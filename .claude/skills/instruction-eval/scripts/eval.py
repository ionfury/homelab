#!/usr/bin/env python3
"""
Instruction evaluation framework — tests Claude skills and CLAUDE.md instructions.

Discovers tests.yaml files in .claude/skills/, runs them against the Claude API
deterministically (temperature=0), and supports git-native A/B comparison.

Usage:
    eval.py run                              # all tests
    eval.py run --skill secrets              # one skill
    eval.py run --category constraint        # by category
    eval.py run --severity critical,high     # by severity
    eval.py run --tag trimmed-2026-03-22     # by tag

    eval.py ab --before main                 # A/B: current vs main branch
    eval.py ab --before HEAD~5               # A/B: current vs 5 commits ago
    eval.py ab --before main --skill secrets # A/B for one skill

    eval.py run --json                       # machine-readable CI output
    eval.py run --report                     # markdown report
    eval.py review results/last-run.json     # list tests needing human review
    eval.py update-verdict SEC-01 PASS [--note "..."]  # record human verdict

Environment:
    ANTHROPIC_API_KEY   Required.
    EVAL_SKILLS_DIR     Override skills directory (default: auto-detect from repo root)
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

try:
    import anthropic
    import yaml
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}\nRun: pip install anthropic pyyaml")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

def find_repo_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True
    )
    return Path(result.stdout.strip())

def get_skills_dir() -> Path:
    if override := os.environ.get("EVAL_SKILLS_DIR"):
        return Path(override)
    return find_repo_root() / ".claude" / "skills"

def get_results_dir() -> Path:
    return get_skills_dir() / "instruction-eval" / "results"

# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

def git_show(ref: str, path: Path) -> Optional[str]:
    """Return file content at git ref, or None if not found."""
    repo_root = find_repo_root()
    relative = path.relative_to(repo_root)
    try:
        result = subprocess.run(
            ["git", "show", f"{ref}:{relative}"],
            capture_output=True, text=True, cwd=repo_root
        )
        return result.stdout if result.returncode == 0 else None
    except Exception:
        return None

def git_head_sha() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        capture_output=True, text=True, check=True
    )
    return result.stdout.strip()

def git_ref_sha(ref: str) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--short", ref],
        capture_output=True, text=True, check=True
    )
    return result.stdout.strip()

# ---------------------------------------------------------------------------
# Test discovery and loading
# ---------------------------------------------------------------------------

def discover_test_files(skills_dir: Path) -> list[Path]:
    """Find all tests.yaml files under skills_dir."""
    return sorted(skills_dir.glob("**/tests.yaml"))

def load_tests_file(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)

def collect_tests(
    skills_dir: Path,
    skill_filter: Optional[str] = None,
    category_filter: Optional[str] = None,
    severity_filter: Optional[set] = None,
    tag_filter: Optional[str] = None,
) -> list[dict]:
    """Collect and filter tests from all discovered tests.yaml files."""
    tests = []
    for path in discover_test_files(skills_dir):
        doc = load_tests_file(path)
        skill_name = doc.get("skill", "unknown")

        if skill_filter and skill_name != skill_filter:
            continue

        for test in doc.get("tests", []):
            test["_skill"] = skill_name
            test["_source"] = str(path)

            if category_filter and test.get("category") != category_filter:
                continue
            if severity_filter and test.get("severity") not in severity_filter:
                continue
            if tag_filter and tag_filter not in test.get("tags", []):
                continue

            tests.append(test)

    return tests

# ---------------------------------------------------------------------------
# System prompt construction
# ---------------------------------------------------------------------------

HOMELAB_CONTEXT = """\
You are Claude Code operating in a homelab infrastructure repository.
This is an enterprise-grade bare-metal Kubernetes platform managed declaratively.
Key technologies: Flux GitOps, Cilium network policies, Terragrunt/OpenTofu,
CloudNative-PG, Grafana/Prometheus/Loki monitoring stack.
Core principles: declarative-only, GitOps-driven, no manual operations,
no secrets in git, use PR workflow for all changes.
"""

def build_system_prompt(skill_content: Optional[str] = None, skill_name: Optional[str] = None) -> str:
    parts = [HOMELAB_CONTEXT]
    if skill_content and skill_name:
        parts.append(f"\n## Active Skill: {skill_name}\n\nThe following skill documentation is loaded:\n\n---\n{skill_content}\n---\n")
    parts.append("\nAnswer based on the homelab's established patterns and constraints.")
    return "\n".join(parts)

def get_skill_content(skills_dir: Path, skill_name: str, git_ref: Optional[str] = None) -> Optional[str]:
    """Load SKILL.md for a skill, optionally from git history."""
    if skill_name in ("repository", "unknown"):
        return None
    skill_file = skills_dir / skill_name / "SKILL.md"
    if git_ref:
        content = git_show(git_ref, skill_file)
        return content
    return skill_file.read_text() if skill_file.exists() else None

# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def score_keywords(response: str, keywords: dict) -> tuple[str, dict]:
    """
    Returns (PASS|PARTIAL|FAIL, details).
    PASS: all required present AND none forbidden present.
    PARTIAL: some required present but not all (no forbidden).
    FAIL: forbidden present OR no required present.
    """
    text = response.lower()

    required = keywords.get("required", [])
    any_of = keywords.get("any_of", [])
    forbidden = keywords.get("forbidden", [])

    matched_required = [kw for kw in required if kw.lower() in text]
    matched_forbidden = [kw for kw in forbidden if kw.lower() in text]
    matched_any = [kw for kw in any_of if kw.lower() in text]

    details = {
        "required_matched": matched_required,
        "required_missing": [kw for kw in required if kw.lower() not in text],
        "forbidden_matched": matched_forbidden,
        "any_of_matched": matched_any,
    }

    if matched_forbidden:
        return "FAIL", details
    if not required:
        return ("PASS" if matched_any else "PARTIAL"), details
    if len(matched_required) == len(required):
        return "PASS", details
    if matched_required:
        return "PARTIAL", details
    return "FAIL", details

def score_judge(client: anthropic.Anthropic, response: str, criteria: str, model: str) -> tuple[int, str]:
    """Ask Claude to score a response 0-10 against judge_criteria. Returns (score, reasoning)."""
    judge_prompt = f"""You are evaluating a Claude response against criteria. Score it 0-10.

CRITERIA:
{criteria}

RESPONSE TO EVALUATE:
{response}

Reply with JSON only: {{"score": N, "reasoning": "brief explanation"}}
Score guide: 9-10=excellent, 7-8=good, 5-6=adequate, 3-4=poor, 0-2=wrong/harmful."""

    msg = client.messages.create(
        model=model,
        max_tokens=256,
        temperature=0,
        messages=[{"role": "user", "content": judge_prompt}]
    )
    try:
        result = json.loads(msg.content[0].text)
        return int(result["score"]), result.get("reasoning", "")
    except Exception:
        # Fallback: extract first number from response
        numbers = re.findall(r'\b([0-9]|10)\b', msg.content[0].text)
        score = int(numbers[0]) if numbers else 5
        return score, msg.content[0].text[:200]

# ---------------------------------------------------------------------------
# Core probe runner
# ---------------------------------------------------------------------------

def run_probe(
    client: anthropic.Anthropic,
    test: dict,
    model: str,
    skill_content: Optional[str] = None,
) -> dict:
    """Run a single test probe and return scored result."""
    skill_name = test.get("_skill")
    system = build_system_prompt(skill_content, skill_name)
    expect_refusal = test.get("expect_refusal", False)

    try:
        msg = client.messages.create(
            model=model,
            max_tokens=1024,
            temperature=0,
            system=system,
            messages=[{"role": "user", "content": test["prompt"]}],
        )
        response = msg.content[0].text
    except Exception as e:
        return {
            "id": test["id"],
            "status": "ERROR",
            "error": str(e),
            "score": 0,
        }

    scoring = test.get("scoring", {})
    mode = scoring.get("mode", "keywords")

    keyword_status, keyword_details = "SKIP", {}
    judge_score, judge_reasoning = None, None

    if mode in ("keywords", "both"):
        keywords = scoring.get("keywords", {})
        if keywords:
            keyword_status, keyword_details = score_keywords(response, keywords)

    if mode in ("judge", "both") and scoring.get("judge_criteria"):
        judge_score, judge_reasoning = score_judge(
            client, response, scoring["judge_criteria"], model
        )

    # Determine final status
    if mode == "keywords":
        status = keyword_status
    elif mode == "judge":
        if judge_score is None:
            status = "ERROR"
        elif judge_score >= 7:
            status = "PASS"
        elif judge_score >= 4:
            status = "PARTIAL"
        else:
            status = "FAIL"
    else:  # both
        if keyword_status == "FAIL" or (judge_score is not None and judge_score < 4):
            status = "FAIL"
        elif keyword_status == "PASS" and (judge_score is None or judge_score >= 7):
            status = "PASS"
        else:
            status = "PARTIAL"

    # Refusal check: if we expected a refusal, reverse logic
    if expect_refusal:
        refusal_signals = ["cannot", "won't", "refuse", "must not", "should not", "inappropriate"]
        is_refusal = any(s in response.lower() for s in refusal_signals)
        if is_refusal and status in ("FAIL", "PARTIAL"):
            status = "PASS"
        elif not is_refusal and status == "PASS":
            status = "FAIL"

    needs_review = test.get("manual_review", False) or status == "PARTIAL"

    return {
        "id": test["id"],
        "skill": skill_name,
        "description": test.get("description", ""),
        "category": test.get("category", ""),
        "severity": test.get("severity", "medium"),
        "status": status,
        "score": judge_score,
        "keyword_status": keyword_status,
        "keyword_details": keyword_details,
        "judge_score": judge_score,
        "judge_reasoning": judge_reasoning,
        "response_snippet": response[:600],
        "needs_review": needs_review,
        "expected_behavior": test.get("expected_behavior", ""),
        "prompt": test["prompt"],
        "human_verdict": None,
        "human_note": None,
    }

# ---------------------------------------------------------------------------
# Run mode
# ---------------------------------------------------------------------------

def cmd_run(args, client: anthropic.Anthropic, skills_dir: Path):
    severity_filter = set(args.severity.split(",")) if args.severity else None
    tests = collect_tests(
        skills_dir,
        skill_filter=args.skill,
        category_filter=args.category,
        severity_filter=severity_filter,
        tag_filter=args.tag,
    )

    if not tests:
        print("No tests found matching filters.")
        sys.exit(0)

    results = []
    for i, test in enumerate(tests):
        skill_content = get_skill_content(skills_dir, test["_skill"])
        if not args.json:
            print(f"[{test['id']}] {test['description']}...", end=" ", flush=True)

        result = run_probe(client, test, args.model, skill_content)
        results.append(result)

        if not args.json:
            icon = {"PASS": "✓", "PARTIAL": "~", "FAIL": "✗", "ERROR": "!", "SKIP": "-"}.get(result["status"], "?")
            score_str = f" ({result['judge_score']}/10)" if result["judge_score"] is not None else ""
            print(f"{icon} {result['status']}{score_str}")
            if result["status"] in ("PARTIAL", "FAIL"):
                if result["keyword_details"].get("required_missing"):
                    print(f"    Missing keywords: {result['keyword_details']['required_missing']}")
                if result["keyword_details"].get("forbidden_matched"):
                    print(f"    Forbidden found: {result['keyword_details']['forbidden_matched']}")

        if i < len(tests) - 1:
            time.sleep(args.delay)

    return _finish_run(results, args, skills_dir, "last-run.json")

# ---------------------------------------------------------------------------
# A/B mode
# ---------------------------------------------------------------------------

def cmd_ab(args, client: anthropic.Anthropic, skills_dir: Path):
    before_ref = args.before
    severity_filter = set(args.severity.split(",")) if args.severity else None

    tests = collect_tests(
        skills_dir,
        skill_filter=args.skill,
        category_filter=args.category,
        severity_filter=severity_filter,
    )

    # Only run tests that have judge_criteria (needed for 0-10 scoring)
    judge_tests = [t for t in tests if t.get("scoring", {}).get("judge_criteria") or t.get("scoring", {}).get("mode") in ("judge", "both")]
    if not judge_tests:
        print("WARNING: No tests with judge_criteria found. A/B requires mode=judge or mode=both.")
        print("Falling back to keyword scoring (PASS/FAIL comparison only).")
        judge_tests = tests

    before_sha = git_ref_sha(before_ref)
    after_sha = git_head_sha()

    if not args.json:
        print(f"\nA/B Comparison: {before_ref} ({before_sha}) → HEAD ({after_sha})\n{'='*60}\n")

    ab_results = []
    for i, test in enumerate(judge_tests):
        skill_name = test.get("_skill")
        before_content = get_skill_content(skills_dir, skill_name, git_ref=before_ref)
        after_content = get_skill_content(skills_dir, skill_name)

        if not args.json:
            print(f"[{test['id']}] {test['description']}")

        before_result = run_probe(client, test, args.model, before_content)
        time.sleep(args.delay)
        after_result = run_probe(client, test, args.model, after_content)

        before_score = before_result.get("judge_score") or (10 if before_result["status"] == "PASS" else 5 if before_result["status"] == "PARTIAL" else 0)
        after_score = after_result.get("judge_score") or (10 if after_result["status"] == "PASS" else 5 if after_result["status"] == "PARTIAL" else 0)
        delta = after_score - before_score

        verdict = "IMPROVED" if delta > 0 else "REGRESSED" if delta < 0 else "UNCHANGED"

        ab_result = {
            "id": test["id"],
            "skill": skill_name,
            "description": test.get("description", ""),
            "severity": test.get("severity", "medium"),
            "before_score": before_score,
            "after_score": after_score,
            "delta": delta,
            "verdict": verdict,
            "before_status": before_result["status"],
            "after_status": after_result["status"],
        }
        ab_results.append(ab_result)

        if not args.json:
            icon = "+" if delta > 0 else "-" if delta < 0 else "="
            print(f"  {icon} {before_score}/10 → {after_score}/10 ({delta:+d}) {verdict}")

        if i < len(judge_tests) - 1:
            time.sleep(args.delay)

    # Summary
    improved = sum(1 for r in ab_results if r["verdict"] == "IMPROVED")
    regressed = sum(1 for r in ab_results if r["verdict"] == "REGRESSED")
    unchanged = sum(1 for r in ab_results if r["verdict"] == "UNCHANGED")

    output = {
        "type": "ab",
        "before_ref": before_ref,
        "before_sha": before_sha,
        "after_sha": after_sha,
        "model": args.model,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "summary": {"improved": improved, "regressed": regressed, "unchanged": unchanged},
        "results": ab_results,
    }

    results_dir = get_results_dir()
    results_dir.mkdir(parents=True, exist_ok=True)
    out_file = results_dir / f"ab-{before_sha}-{after_sha}.json"
    out_file.write_text(json.dumps(output, indent=2))

    if args.json:
        print(json.dumps(output, indent=2))
    else:
        print(f"\n{'='*60}")
        print(f"IMPROVED: {improved}  REGRESSED: {regressed}  UNCHANGED: {unchanged}")
        print(f"Saved to: {out_file}")

        if regressed > 0:
            print("\nRegressions:")
            for r in ab_results:
                if r["verdict"] == "REGRESSED":
                    sev = r["severity"]
                    print(f"  [{r['id']}] {r['description']} ({sev}) {r['before_score']} → {r['after_score']}")
            critical_regressions = [r for r in ab_results if r["verdict"] == "REGRESSED" and r["severity"] in ("critical", "high")]
            if critical_regressions:
                sys.exit(1)

# ---------------------------------------------------------------------------
# Review mode
# ---------------------------------------------------------------------------

def cmd_review(args):
    results_path = Path(args.results_file)
    if not results_path.exists():
        print(f"ERROR: {results_path} not found")
        sys.exit(1)

    data = json.loads(results_path.read_text())
    results = data.get("results", [])
    needs_review = [r for r in results if r.get("needs_review") and r.get("human_verdict") is None]

    if not needs_review:
        print("No tests pending human review.")
        return

    print(f"\n{len(needs_review)} test(s) need human review:\n")
    for r in needs_review:
        print(f"  [{r['id']}] {r['description']} — {r['status']}")
        print(f"    Prompt: {r['prompt'][:100]}...")
        print(f"    Response: {r['response_snippet'][:200]}...")
        print(f"    Expected: {r['expected_behavior'][:150]}")
        print()

    print("Use: eval.py update-verdict <ID> PASS|FAIL [--note '...']")

# ---------------------------------------------------------------------------
# Update-verdict mode
# ---------------------------------------------------------------------------

def cmd_update_verdict(args):
    results_dir = get_results_dir()
    last_run = results_dir / "last-run.json"
    if not last_run.exists():
        print("ERROR: No last-run.json found. Run tests first.")
        sys.exit(1)

    data = json.loads(last_run.read_text())
    for result in data.get("results", []):
        if result["id"] == args.probe_id:
            result["human_verdict"] = args.verdict
            result["human_note"] = args.note
            result["needs_review"] = False
            break
    else:
        print(f"ERROR: Probe {args.probe_id} not found in last-run.json")
        sys.exit(1)

    last_run.write_text(json.dumps(data, indent=2))
    print(f"Updated {args.probe_id}: {args.verdict}")

# ---------------------------------------------------------------------------
# Finish run: save results, print summary, exit with correct code
# ---------------------------------------------------------------------------

def _finish_run(results: list[dict], args, skills_dir: Path, filename: str) -> int:
    counts = {s: sum(1 for r in results if r["status"] == s) for s in ("PASS", "PARTIAL", "FAIL", "ERROR")}

    output = {
        "type": "run",
        "model": args.model,
        "git_sha": git_head_sha(),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "filters": {
            "skill": getattr(args, "skill", None),
            "category": getattr(args, "category", None),
            "severity": getattr(args, "severity", None),
        },
        "counts": counts,
        "results": results,
    }

    results_dir = get_results_dir()
    results_dir.mkdir(parents=True, exist_ok=True)
    out_file = results_dir / filename
    out_file.write_text(json.dumps(output, indent=2))

    if args.json:
        print(json.dumps(output, indent=2))
    elif getattr(args, "report", False):
        _print_report(output)
    else:
        print(f"\n{'='*60}")
        print(f"PASS: {counts['PASS']}  PARTIAL: {counts['PARTIAL']}  FAIL: {counts['FAIL']}  ERROR: {counts['ERROR']}")
        review_count = sum(1 for r in results if r.get("needs_review") and r.get("human_verdict") is None)
        if review_count:
            print(f"Human review needed: {review_count} (run: eval.py review results/last-run.json)")
        print(f"Saved to: {out_file}")

    # Exit code: 1 if any critical/high severity tests failed
    critical_failures = [r for r in results if r["status"] in ("FAIL", "ERROR") and r.get("severity") in ("critical", "high")]
    return 1 if critical_failures else 0

def _print_report(output: dict):
    print(f"\n# Instruction Eval Report")
    print(f"Model: {output['model']} | SHA: {output['git_sha']} | {output['timestamp']}\n")
    counts = output["counts"]
    print(f"| Status | Count |")
    print(f"|--------|-------|")
    for s, c in counts.items():
        print(f"| {s} | {c} |")

    by_skill: dict[str, list] = {}
    for r in output["results"]:
        by_skill.setdefault(r["skill"], []).append(r)

    for skill, skill_results in sorted(by_skill.items()):
        print(f"\n## {skill}")
        for r in skill_results:
            icon = {"PASS": "✓", "PARTIAL": "~", "FAIL": "✗", "ERROR": "!"}.get(r["status"], "?")
            score_str = f" {r['judge_score']}/10" if r.get("judge_score") is not None else ""
            print(f"  {icon} [{r['id']}] {r['description']}{score_str}")
            if r["status"] in ("PARTIAL", "FAIL"):
                print(f"     Expected: {r['expected_behavior'][:100]}")

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Instruction eval framework")
    parser.add_argument("--model", default="claude-sonnet-4-6")
    parser.add_argument("--delay", type=float, default=0.5, help="Seconds between API calls")
    parser.add_argument("--json", action="store_true")

    sub = parser.add_subparsers(dest="command", required=True)

    # run
    p_run = sub.add_parser("run", help="Run tests")
    p_run.add_argument("--skill")
    p_run.add_argument("--category")
    p_run.add_argument("--severity", help="Comma-separated: critical,high,medium,low")
    p_run.add_argument("--tag")
    p_run.add_argument("--report", action="store_true")

    # ab
    p_ab = sub.add_parser("ab", help="A/B test against git ref")
    p_ab.add_argument("--before", required=True, help="Git ref for 'before' state")
    p_ab.add_argument("--skill")
    p_ab.add_argument("--category")
    p_ab.add_argument("--severity")

    # review
    p_rev = sub.add_parser("review", help="List tests needing human review")
    p_rev.add_argument("results_file", nargs="?", default="results/last-run.json")

    # update-verdict
    p_uv = sub.add_parser("update-verdict", help="Record human verdict")
    p_uv.add_argument("probe_id")
    p_uv.add_argument("verdict", choices=["PASS", "FAIL"])
    p_uv.add_argument("--note", default=None)

    args = parser.parse_args()

    if args.command in ("run", "ab"):
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("ERROR: ANTHROPIC_API_KEY not set")
            sys.exit(1)
        client = anthropic.Anthropic(api_key=api_key)
        skills_dir = get_skills_dir()

        if args.command == "run":
            exit_code = cmd_run(args, client, skills_dir)
            sys.exit(exit_code)
        else:
            cmd_ab(args, client, skills_dir)

    elif args.command == "review":
        cmd_review(args)

    elif args.command == "update-verdict":
        cmd_update_verdict(args)

if __name__ == "__main__":
    main()

data "aws_iam_policy_document" "read_ssm" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter*"]
    resources = ["arn:aws:ssm:us-east-2:850584657866:parameter/${var.name}-*"]
  }
}

resource "aws_iam_user" "this" {
  name = "${var.name}-read-ssm"
}

resource "aws_iam_user_policy" "read_ssm" {
  name   = "${var.name}-read-ssm"
  user   = aws_iam_user.this.name
  policy = data.aws_iam_policy_document.read_ssm.json
}

resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}

# Layout Conventions Reference

The Grafana grid is **24 columns wide**. All positioning uses `gridPos: { h, w, x, y }`.

## Standard Widths and Heights

| Columns (w) | Layout | Typical Use |
|-------------|--------|-------------|
| 24 | Full width | Wide timeseries, full-width tables |
| 12 | Half | Side-by-side panels |
| 8 | Third | Three equal panels per row (most common) |
| 6 | Quarter | Four stat panels across a row |
| 4 | Sixth | Six compact stat panels |

| Height (h) | Typical Use |
|------------|-------------|
| 1 | Row separator |
| 4 | Small stat panels |
| 5 | Medium stat panels |
| 6 | Stat panels with sparkline |
| 8 | Standard timeseries/gauge panels |
| 10 | Tall timeseries or tables |

## Row Panel

Rows are section headers that group panels:

```json
{
  "collapsed": false,
  "gridPos": { "h": 1, "w": 24, "x": 0, "y": 0 },
  "id": 10,
  "title": "Section Name",
  "type": "row"
}
```

## Layout Rules

- Rows always at `x: 0, w: 24, h: 1`
- After a row, panels start at `y: row_y + 1`
- Panels on the same horizontal line share the same `y`
- Increment `y` by panel `h` to get the next row's starting `y`
- Section IDs are multiples of 10 (10, 20, 30...) for easy insertion
- Panel IDs within a section are sequential from the section base

## Common Layout Patterns

**Three equal panels (most common):**
```
Row:   { h:1,  w:24, x:0,  y:0  }
Left:  { h:8,  w:8,  x:0,  y:1  }
Mid:   { h:8,  w:8,  x:8,  y:1  }
Right: { h:8,  w:8,  x:16, y:1  }
Next:  y=9
```

**Four stat panels:**
```
Row:   { h:1,  w:24, x:0,  y:0  }
S1:    { h:4,  w:6,  x:0,  y:1  }
S2:    { h:4,  w:6,  x:6,  y:1  }
S3:    { h:4,  w:6,  x:12, y:1  }
S4:    { h:4,  w:6,  x:18, y:1  }
Next:  y=5
```

**Six compact stat panels:**
```
S1-S6: { h:4, w:4, x:0/4/8/12/16/20, y:1 }
```

**Stats row + timeseries below:**
```
Row:    { h:1,  w:24, x:0,  y:0  }
S1-S4:  { h:4,  w:6,  x:0/6/12/18, y:1  }
Chart1: { h:8,  w:12, x:0,  y:5  }
Chart2: { h:8,  w:12, x:12, y:5  }
Next:   y=13
```

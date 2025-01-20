# Database Comparison Tool

A simple tool to compare two Ruwido databases and check for differences in their responses.

## Features

- Compares brand counts between databases
- Verifies signal order consistency
- Provides clear, colored output with detailed differences
- Shows summary of all comparisons

## Usage

Simply run:
```bash
python3 test_database.py
```

## Endpoints Tested

1. `list/tv/` - Compares the number of brands between databases
2. `empty/signal` - Verifies that signal orders match between databases

## Output

The tool provides:
- Step-by-step testing information
- Detailed comparison results
- Examples of differences when found
- Final summary with pass/fail status

## Requirements

- Python 3
- Required packages: requests, lxml

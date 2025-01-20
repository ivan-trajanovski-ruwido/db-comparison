# Database Comparison Tool

A simple tool to compare two Ruwido databases and check for differences in their responses.

## Setup

1. Activate the virtual environment:
```bash
source ruwido-db-env/bin/activate  
```

2. Verify you're in the virtual environment:
```bash
which python  # Should show path ending in ruwido-db-env/bin/python
```

## Features

- Compares brand counts between databases
- Verifies signal order consistency
- Provides clear, colored output with detailed differences
- Shows summary of all comparisons

## Usage

With the virtual environment activated, run:
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
- Virtual environment: `ruwido-db-env`
- Required packages: requests, lxml

## Development

To create a new virtual environment (if needed):
```bash
python3 -m venv ruwido-db-env
source ruwido-db-env/bin/activate
pip install requests lxml
```

# Database Comparison Tool

A simple tool to compare two Ruwido databases and check for differences in their responses.

## Setup

1. Activate the virtual environment:
```bash
source ruwido-db-env/bin/activate  # On macOS/Linux
```

2. Verify you're in the virtual environment:
```bash
which python  # Should show path ending in ruwido-db-env/bin/python
```

## Features

- Compares brand counts between databases
- Verifies signal order consistency
- Provides clear, colored output with detailed differences
- Shows bilingual summary (English/German) of all comparisons
- Generates detailed markdown reports of differences

## Usage

With the virtual environment activated, you have two options:

1. Basic comparison:
```bash
python3 test_database.py
```

2. Detailed comparison report:
```bash
python3 test_database.py --detailed-diff
```

The `--detailed-diff` option generates a detailed markdown report (`db_comparison_report_YYYYMMDD_HHMMSS.md`) that includes:
- Complete list of brands present in the new DB but not in production
- Complete list of brands present in production but missing from the new DB
- Bilingual descriptions (English/German) for better accessibility
- Summary of total changes across all endpoints

The report is formatted in markdown.

## Endpoints Tested

The tool uses an endpoint configuration system that makes it easy to add new endpoints. Currently configured endpoints:

1. `list/tv/` - Compares the number of TV brands
2. `list/stb/` - Compares the number of Set-top box brands
3. `empty/signal` - Verifies that signal orders match

## Adding a New Endpoint

To add a new endpoint for testing:

1. Open `test_database.py`
2. Locate the `ENDPOINT_CONFIG` dictionary at the top of the file
3. Add your new endpoint using the format:
```python
'endpoint/path': ('Description', 'test_function')
```

Available test functions:
- `compare_brands` - For comparing number of brands
- `compare_signal_order` - For comparing signal order in XML responses

Example:
```python
ENDPOINT_CONFIG = {
    'list/tv/': ('TV brands comparison', 'compare_brands'),
    'your/new/endpoint': ('Your description', 'compare_brands')
}
```

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

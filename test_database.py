import requests
import json
from lxml import etree
import time

# Database URLs
CURRENT_DB_URL = "https://ruwido.api.ruwido.com/rc_config/9385807aba71/v2/"
NEW_DB_URL = "http://10.11.101.42:81/rc_config/9385807aba71/v2/"

# Output formatting
GREEN = '\033[92m'
RED = '\033[91m'
BLUE = '\033[94m'
YELLOW = '\033[93m'
BOLD = '\033[1m'
RESET = '\033[0m'

# Test endpoints
TEST_URLS = ["list/tv/", "empty/signal"]
differences_summary = []

def fetch_response(url):
    """Send a GET request and return the response content."""
    try:
        response = requests.get(url)
        response.raise_for_status()
        if len(response.content) == 0:
            raise RuntimeError(f"Empty response received from {url}")
        return response.content
    except requests.exceptions.RequestException as err:
        raise RuntimeError(f"Failed to fetch: {err}")

def parse_response(content):
    """Parse the response content as XML or JSON."""
    if not content:
        return None, None

    try:
        return json.loads(content), 'json'
    except json.JSONDecodeError:
        try:
            return etree.fromstring(content), 'xml'
        except etree.XMLSyntaxError:
            return None, None

def count_brands(data):
    """Count the number of brands."""
    if isinstance(data, list):
        return sum(count_brands(item) for item in data)
    elif isinstance(data, dict):
        return sum(count_brands(value) for value in data.values())
    else:
        return 1

def compare_brands(current_data, new_data, url_part):
    """Compare brands in the responses."""
    current_total = count_brands(current_data)
    new_total = count_brands(new_data)
    total_diff = new_total - current_total

    print(f"  {YELLOW}Production DB:{RESET} {current_total} brands")
    print(f"  {YELLOW}New DB:{RESET} {new_total} brands")
    
    if total_diff != 0:
        msg = f"Brand count difference: {abs(total_diff)} {'more' if total_diff > 0 else 'less'} in New DB"
        print(f"  {RED}→ {msg}{RESET}")
        differences_summary.append((url_part, False, msg))
    else:
        print(f"  {GREEN}→ Brand counts match{RESET}")
        differences_summary.append((url_part, True, "Brand counts match"))

def compare_signal_order(current_data, new_data):
    """Compare the order of signals."""
    current_signals = [signal.get('name') for signal in current_data.findall('.//signal')]
    new_signals = [signal.get('name') for signal in new_data.findall('.//signal')]

    print(f"  {YELLOW}Production DB:{RESET} {len(current_signals)} signals")
    print(f"  {YELLOW}New DB:{RESET} {len(new_signals)} signals")

    if current_signals != new_signals:
        diff_count = sum(1 for c, n in zip(current_signals, new_signals) if c != n)
        msg = f"{diff_count} signal order differences"
        print(f"  {RED}→ {msg}{RESET}")
        
        # Show first 3 differences as example
        for i, (curr, new) in enumerate(zip(current_signals, new_signals)):
            if curr != new and i < 3:
                print(f"    Example: Position {i}: {YELLOW}{curr}{RESET} → {BLUE}{new}{RESET}")
        
        differences_summary.append(("empty/signal", False, msg))
    else:
        print(f"  {GREEN}→ Signal order matches{RESET}")
        differences_summary.append(("empty/signal", True, "Signal order matches"))

def compare_responses(current_url, new_url):
    """Compare the responses from the current and new DB."""
    endpoint = current_url.split("v2/")[-1]
    print(f"\n{BOLD}Testing endpoint:{RESET} {YELLOW}{endpoint}{RESET}")
    print(f"{'─' * 50}")
    
    try:
        current_response = fetch_response(current_url)
        new_response = fetch_response(new_url)
    except RuntimeError as e:
        print(f"  {RED}→ {str(e)}{RESET}")
        differences_summary.append((endpoint, False, str(e)))
        return

    current_data, current_type = parse_response(current_response)
    new_data, new_type = parse_response(new_response)

    if current_data is None or new_data is None or current_type != new_type:
        msg = "Invalid or mismatched response formats"
        print(f"  {RED}→ {msg}{RESET}")
        differences_summary.append((endpoint, False, msg))
        return

    if endpoint == "list/tv/":
        print(f"  {BLUE}Testing brand counts...{RESET}")
        compare_brands(current_data, new_data, endpoint)
    elif endpoint == "empty/signal":
        print(f"  {BLUE}Testing signal order...{RESET}")
        if current_type == 'xml':
            compare_signal_order(current_data, new_data)
        else:
            msg = "Non-XML response for signal comparison"
            print(f"  {RED}→ {msg}{RESET}")
            differences_summary.append((endpoint, False, msg))

def print_summary(total_time):
    """Print a summary of all comparisons."""
    print(f"\n{BOLD}{'='*50}{RESET}")
    print(f"{BOLD}DATABASE COMPARISON SUMMARY{RESET}")
    print(f"{BOLD}{'='*50}{RESET}")
    
    for url_part, passed, details in differences_summary:
        status = f"{GREEN}✓ PASS{RESET}" if passed else f"{RED}✗ FAIL{RESET}"
        print(f"{status} | {url_part:<15} | {details}")
    
    all_passed = all(result[1] for result in differences_summary)
    print(f"\n{BOLD}Time:{RESET} {total_time:.2f}s")
    print(f"{BOLD}Status:{RESET} {GREEN}PASSED{RESET}" if all_passed else f"{RED}FAILED{RESET}")
    print(f"{BOLD}{'='*50}{RESET}")

if __name__ == "__main__":
    print(f"\n{BOLD}DATABASE COMPARISON TEST{RESET}")
    print(f"{BOLD}{'='*50}{RESET}")
    print(f"{BLUE}Production DB:{RESET} {CURRENT_DB_URL}")
    print(f"{BLUE}New DB:{RESET} {NEW_DB_URL}")
    
    start_time = time.time()
    
    for test_url in TEST_URLS:
        current_url = CURRENT_DB_URL + test_url
        new_url = NEW_DB_URL + test_url
        compare_responses(current_url, new_url)
    
    print_summary(time.time() - start_time)

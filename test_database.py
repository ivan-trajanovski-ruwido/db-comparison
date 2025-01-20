import requests
import json
from lxml import etree

CURRENT_DB_URL = "https://ruwido.api.ruwido.com/rc_config/9385807aba71/v2/"
NEW_DB_URL = "http://10.11.101.42:81/rc_config/9385807aba71/v2/"

# Colors for output
RED = '\033[91m'
GREEN = '\033[92m'
RESET = '\033[0m'

TEST_URLS = ["list/tv/", "empty/signal"]

differences_summary = []

def fetch_response(url):
    """Send a GET request and return the response content."""
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.content 
    except requests.exceptions.RequestException as err:
        raise RuntimeError(f"An error occurred: {err} for URL: {url}") from err

def parse_response(content):
    """Parse the response content as XML or JSON."""
    if not content:
        print(f"{RED}Empty response received.{RESET}")
        return None, None

    try:
        data = json.loads(content) 
        return data, 'json'
    except json.JSONDecodeError:
        try:
            root = etree.fromstring(content)  
            return root, 'xml'
        except etree.XMLSyntaxError as err:
            print(f"{RED}Invalid response format. Error: {err}. Content: {content.decode('utf-8')[:200]}{RESET}")
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

    print(f"\n{RED}Checking for differences in brands for {url_part}{RESET}")
    print(f"Total number of brands in current URL: {current_total}")
    print(f"Total number of brands in new URL: {new_total}")
    if total_diff != 0:
        print(f"{RED}THERE IS A DIFFERENCE in total brands: {total_diff} {'(more)' if total_diff > 0 else '(less)'}{RESET}")
        differences_summary.append((url_part, False))
    else:
        print(f"{GREEN}NO DIFFERENCES FOUND in total brands{RESET}")
        differences_summary.append((url_part, True))

def compare_signal_order(current_data, new_data):
    """Compare the order of signals."""
    current_signals = [signal.get('name') for signal in current_data.findall('.//signal')]
    new_signals = [signal.get('name') for signal in new_data.findall('.//signal')]

    print(f"\n{RED}Testing for differences in signal order{RESET}")
    if current_signals != new_signals:
        print(f"{RED}THERE ARE DIFFERENCES in signal order:{RESET}")
        print(f"Current order: {current_signals}")
        print(f"New order: {new_signals}")
        differences_summary.append(("empty/signal/", False))
    else:
        print(f"{GREEN}NO DIFFERENCES FOUND in signal order{RESET}")
        differences_summary.append(("empty/signal/", True))

def compare_responses(current_url, new_url):
    """Compare the responses from the current and new DB."""
    try:
        current_response = fetch_response(current_url)
        new_response = fetch_response(new_url)
    except RuntimeError as e:
        print(e)
        differences_summary.append((current_url.split("v2/")[-1], False))
        return

    current_data, current_type = parse_response(current_response)
    new_data, new_type = parse_response(new_response)

    if current_data is None or new_data is None:
        print(f"{RED}Skipping comparison due to empty response.{RESET}")
        differences_summary.append((current_url.split("v2/")[-1], False))
        return

    url_part_after_v2 = current_url.split("v2/")[-1]

    if current_type != new_type:
        print(f"{RED}Response types do not match for URLs: {current_url} and {new_url}{RESET}")
        differences_summary.append((url_part_after_v2, False))
        return

    if url_part_after_v2 == "list/tv/":
        compare_brands(current_data, new_data, url_part_after_v2)
    elif url_part_after_v2 == "empty/signal/":
        if current_type == 'xml':
            compare_signal_order(current_data, new_data)
        else:
            print(f"{RED}Signal order comparison is only supported for XML responses.{RESET}")
            differences_summary.append((url_part_after_v2, False))
    else:
        print(f"{RED}Unsupported URL: {current_url}{RESET}")
        differences_summary.append((url_part_after_v2, False))

if __name__ == "__main__":
    for test_url in TEST_URLS:
        current_url = CURRENT_DB_URL + test_url
        new_url = NEW_DB_URL + test_url

        print(f"\n{GREEN}Testing URL: {current_url}{RESET}")
        compare_responses(current_url, new_url)

    print(f"\n{GREEN}=== SUMMARY ==={RESET}")
    for url_part, no_diff in differences_summary:
        if no_diff:
            print(f"{GREEN}NO DIFFERENCES found for {url_part}{RESET}")
        else:
            print(f"{RED}DIFFERENCES found for {url_part}{RESET}")

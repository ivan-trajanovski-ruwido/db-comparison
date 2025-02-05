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

# Endpoint Configuration
# Format: 'endpoint': ('description', test_function)
ENDPOINT_CONFIG = {
    'list/tv/': ('TV brands comparison', 'compare_brands'),
    'list/stb/': ('Set-top box brands comparison', 'compare_brands'),
    'empty/signal': ('Signal order verification', 'compare_signal_order')
}

TEST_ENDPOINTS = list(ENDPOINT_CONFIG.keys())
differences_summary = []

def fetch_response(url):
    """Send a GET request and return the response content."""
    try:
        # Use XML for signal endpoints, JSON for everything else
        if 'signal' in url:
            headers = {'Accept': 'application/xml'}
        else:
            headers = {'Accept': 'application/json'}
        
        response = requests.get(url, headers=headers)
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
    # For JSON response (list/tv endpoint)
    if isinstance(data, list):
        return len(data)
    # For XML response
    elif isinstance(data, etree._Element):
        remotes = data.find('remotes')
        if remotes is not None:
            return int(remotes.get('total', 0))
        return 0
    # For other cases
    return 0

# Global variable to store detailed differences
detailed_differences = {}

def compare_brands(current_data, new_data, url_part):
    """Compare brands in the responses."""
    current_total = count_brands(current_data)
    new_total = count_brands(new_data)
    total_diff = new_total - current_total

    print(f"  {YELLOW}Production DB:{RESET} {current_total} brands")
    print(f"  {YELLOW}New DB:{RESET} {new_total} brands")
    
    # If detailed diff is requested, collect the differences
    if args.detailed_diff:
        current_brands = {b['id']: b for b in current_data} if isinstance(current_data, list) else {}
        new_brands = {b['id']: b for b in new_data} if isinstance(new_data, list) else {}
        
        new_only = [b for b in new_brands.values() if b['id'] not in current_brands]
        prod_only = [b for b in current_brands.values() if b['id'] not in new_brands]
        
        detailed_differences[url_part] = {
            'differences': bool(new_only or prod_only),
            'new_only': new_only,
            'prod_only': prod_only
        }
    
    if total_diff != 0:
        msg = f"Brand count difference: {abs(total_diff)} {'more' if total_diff > 0 else 'less'} in New DB"
        print(f"  {RED}→ {msg}{RESET}")
        differences_summary.append((url_part, False, msg))
    else:
        print(f"  {GREEN}→ Brand counts match{RESET}")
        differences_summary.append((url_part, True, "Brand counts match"))

def compare_signal_order(current_data, new_data, url_part):
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
        
        differences_summary.append((url_part, False, msg))
    else:
        print(f"  {GREEN}→ Signal order matches{RESET}")
        differences_summary.append((url_part, True, "Signal order matches"))

def compare_responses(current_url, new_url):
    """Compare the responses from the current and new DB."""
    endpoint = current_url.split("v2/")[-1]
    description = ENDPOINT_CONFIG[endpoint][0]
    test_function = globals()[ENDPOINT_CONFIG[endpoint][1]]
    
    print(f"\n{BOLD}Testing endpoint:{RESET} {YELLOW}{endpoint}{RESET}")
    print(f"{BOLD}Test type:{RESET} {description}")
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

    if endpoint.endswith('signal'):
        if current_type != 'xml':
            msg = "Non-XML response for signal comparison"
            print(f"  {RED}→ {msg}{RESET}")
            differences_summary.append((endpoint, False, msg))
            return

    test_function(current_data, new_data, endpoint)

def print_summary(total_time):
    """Print a summary of all comparisons."""
    print(f"\n{BOLD}{'='*50}{RESET}")
    print(f"{BOLD}DATABASE COMPARISON SUMMARY / DATENBANKVERGLEICH ZUSAMMENFASSUNG{RESET}")
    print(f"{BOLD}{'='*50}{RESET}")
    
    for url_part, passed, details in differences_summary:
        status = f"{GREEN}✓ BESTANDEN{RESET}" if passed else f"{RED}✗ FEHLGESCHLAGEN{RESET}"
        description = ENDPOINT_CONFIG[url_part][0]
        
        # Translate the details message
        de_details = details
        if "Brand counts match" in details:
            de_details = "Markenanzahl stimmt überein"
        elif "Brand count difference:" in details:
            count = details.split(': ')[1].split(' ')[0]
            more_less = "mehr" if "more" in details else "weniger"
            de_details = f"Unterschied in der Markenanzahl: {count} {more_less} in der neuen DB"
        elif "Signal order matches" in details:
            de_details = "Signalreihenfolge stimmt überein"
        elif "Empty response received" in details:
            de_details = "Leere Antwort erhalten"
        elif "Invalid or mismatched response formats" in details:
            de_details = "Ungültige oder nicht übereinstimmende Antwortformate"
        
        print(f"{status} | {url_part:<15} | {description:<25} | {details} / {de_details}")
    
    all_passed = all(result[1] for result in differences_summary)
    print(f"\n{BOLD}Time / Zeit:{RESET} {total_time:.2f}s")
    status_text = f"{GREEN}PASSED / BESTANDEN{RESET}" if all_passed else f"{RED}FAILED / FEHLGESCHLAGEN{RESET}"
    print(f"{BOLD}Status:{RESET} {status_text}")
    print(f"{BOLD}{'='*50}{RESET}")

def generate_detailed_report(differences):
    """Generate a detailed markdown report of the differences."""
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    filename = f"db_comparison_report_{timestamp}.md"
    
    with open(filename, 'w') as f:
        # Title and header
        f.write("# Database Comparison Report / Datenbankvergleichsbericht\n\n")
        f.write(f"Generated / Erstellt am: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("## Database Information / Datenbankinformationen\n\n")
        f.write(f"Production Database / Produktionsdatenbank:\n`{CURRENT_DB_URL}`\n\n")
        f.write(f"New Database / Neue Datenbank:\n`{NEW_DB_URL}`\n\n")
        f.write("---\n\n")
        
        # Summary section
        f.write("## Summary / Zusammenfassung\n\n")
        total_new = sum(len(d['new_only']) for d in differences.values())
        total_missing = sum(len(d['prod_only']) for d in differences.values())
        
        if total_new == 0 and total_missing == 0:
            f.write("🟢 **No differences found** / **Keine Unterschiede gefunden**\n\n")
        else:
            f.write(f"### Overall Changes / Gesamtänderungen:\n")
            if total_new > 0:
                f.write(f"- 🆕 **{total_new}** new brands in the new database / neue Marken in der neuen Datenbank\n")
            if total_missing > 0:
                f.write(f"- ❌ **{total_missing}** brands missing from new database / Marken fehlen in der neuen Datenbank\n")
            f.write("\n")
        
        f.write("---\n\n")
        
        # Detailed differences by endpoint
        f.write("## Detailed Analysis / Detaillierte Analyse\n\n")
        for endpoint, diff_data in differences.items():
            f.write(f"### {endpoint}\n\n")
            
            if not diff_data['differences']:
                f.write("✅ **No differences found in this endpoint** / **Keine Unterschiede in diesem Endpunkt gefunden**\n\n")
                continue
            
            # New brands section
            new_count = len(diff_data['new_only'])
            if new_count > 0:
                f.write(f"#### 🆕 New Brands / Neue Marken ({new_count})\n")
                f.write("*These brands are present in the new database but not in the production database* /\n")
                f.write("*Diese Marken sind in der neuen Datenbank vorhanden, aber nicht in der Produktionsdatenbank*\n\n")
                for brand in sorted(diff_data['new_only'], key=lambda x: x['label'].lower()):
                    f.write(f"- **{brand['label']}** (ID: `{brand['id']}`)\n")
                f.write("\n")
            
            # Missing brands section
            missing_count = len(diff_data['prod_only'])
            if missing_count > 0:
                f.write(f"#### ❌ Missing Brands / Fehlende Marken ({missing_count})\n")
                f.write("*These brands are present in the production database but missing from the new database* /\n")
                f.write("*Diese Marken sind in der Produktionsdatenbank vorhanden, fehlen aber in der neuen Datenbank*\n\n")
                for brand in sorted(diff_data['prod_only'], key=lambda x: x['label'].lower()):
                    f.write(f"- **{brand['label']}** (ID: `{brand['id']}`)\n")
                f.write("\n")
            
            f.write("---\n\n")
    
    print(f"\n📄 Detailed report generated / Detaillierter Bericht erstellt: {filename}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Compare two database instances')
    parser.add_argument('--detailed-diff', action='store_true',
                      help='Generate a detailed report of differences')
    args = parser.parse_args()
    
    print(f"\n{BOLD}DATABASE COMPARISON TEST{RESET}")
    print(f"{BOLD}{'='*50}{RESET}")
    print(f"{BLUE}Production DB:{RESET} {CURRENT_DB_URL}")
    print(f"{BLUE}New DB:{RESET} {NEW_DB_URL}")
    
    start_time = time.time()
    
    for test_url in TEST_ENDPOINTS:
        current_url = CURRENT_DB_URL + test_url
        new_url = NEW_DB_URL + test_url
        compare_responses(current_url, new_url)
    
    print_summary(time.time() - start_time)
    
    # Generate detailed report if requested
    if args.detailed_diff:
        generate_detailed_report(detailed_differences)

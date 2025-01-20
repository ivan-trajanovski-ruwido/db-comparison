import pytest
import requests
from lxml import etree
import json
from deepdiff import DeepDiff

CURRENT_BASE_URL = "http://ruwido.api.ruwido.com/rc_config/9385807aba71/v2/list/"
NEW_BASE_URL = "http://10.11.101.42:81/rc_config/9385807aba71/v2/list/"

TEST_URLS = [
    "",
    "tv/",
]

def fetch_response(url):
    """Send a GET request."""
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.content
    except requests.exceptions.HTTPError as http_err:
        raise RuntimeError(f"HTTP error occurred: {http_err} for URL: {url}") from http_err
    except Exception as err:
        raise RuntimeError(f"An error occurred: {err} for URL: {url}") from err

def parse_response(content):
    """Parse response content and determine if it is XML or JSON."""
    try:
        # Try parsing as XML
        return etree.fromstring(content), 'xml'
    except etree.XMLSyntaxError:
        # If XML parsing fails, try parsing as JSON
        try:
            return json.loads(content), 'json'
        except json.JSONDecodeError as e:
            raise RuntimeError(f"Invalid response format. Error: {e}. Content: {content.decode('utf-8')[:200]}")

def compare_responses(current_url, new_url):
    """Compare the responses from the current and new URLs."""
    current_response = fetch_response(current_url)
    new_response = fetch_response(new_url)

    current_data, current_type = parse_response(current_response)
    new_data, new_type = parse_response(new_response)

    if current_type != new_type:
        raise RuntimeError(f"Response types do not match for URLs: {current_url} and {new_url}")

    if current_type == 'xml':
        current_str = etree.tostring(current_data)
        new_str = etree.tostring(new_data)
        if current_str != new_str:
            print(f"Responses differ for URL: {current_url}")
            diff = DeepDiff(current_data, new_data, ignore_order=True)

            missing_from_current = []
            missing_from_new = []

            for key, value in diff.items():
                if key.startswith('root'):
                    if 'added' in value[0]:
                        missing_from_current.append(key)
                    elif 'removed' in value[0]:
                        missing_from_new.append(key)

            # Extract the total value from the XML data
            current_total = int(current_data.find('brands').get('total', 0))
            new_total = int(new_data.find('brands').get('total', 0))

            if current_total != new_total:
                print(f"Total value differs. Current: {current_total}, New: {new_total}")

            if missing_from_current:
                print(f"{len(missing_from_current)} items are missing from the current URL that are present in the new URL:")
                for item in missing_from_current:
                    brand_name = new_data.find(f"./{item.replace('root', '')}/name").text
                    print(f"- {brand_name}")

            if missing_from_new:
                print(f"{len(missing_from_new)} items are missing from the new URL that are present in the current URL:")
                for item in missing_from_new:
                    brand_name = current_data.find(f"./{item.replace('root', '')}/name").text
                    print(f"- {brand_name}")

            return False, diff

        return True, None
    elif current_type == 'json':
        if current_data != new_data:
            diff = DeepDiff(current_data, new_data, ignore_order=True).pretty()
            return False, diff
        return True, None
    else:
        raise RuntimeError("Unknown response type")

@pytest.mark.parametrize("test_url", TEST_URLS)
def test_database_comparison(test_url):
    """Test the comparison of responses."""
    current_url = CURRENT_BASE_URL + test_url
    new_url = NEW_BASE_URL + test_url

    print(f"Testing URL: {current_url}")

    try:
        result, diff = compare_responses(current_url, new_url)
        if result:
            print(f"Test passed for URL: {current_url}")
        else:
            print(f"Test failed for URL: {current_url}")
            print(f"Differences: {diff}")
            assert result, f"Responses differ for URL: {current_url}. Differences: {diff}"
    except RuntimeError as e:
        print(f"Test failed for URL: {current_url}")
        print(str(e))
        pytest.fail(str(e))

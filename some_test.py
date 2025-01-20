import requests

reqUrl = "http://10.11.101.42:81/rc_config/9385807aba71/v2/empty/signal"

headersList = {
 "Accept": "*/*",
 "User-Agent": "Thunder Client (https://www.thunderclient.com)" 
}

payload = ""

response = requests.request("GET", reqUrl, data=payload,  headers=headersList)

print(response.text)
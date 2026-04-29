import json
import urllib.request
import sys

url = 'http://13.53.102.145/api/auth/apple/'
data = json.dumps({"access_token": "fake_token_123"}).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json', 'Accept': 'application/json'})

try:
    response = urllib.request.urlopen(req)
    with open('error.html', 'w') as f:
        f.write(response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    with open('error.html', 'w') as f:
        f.write(e.read().decode('utf-8'))
except Exception as e:
    print(f"Error: {e}")

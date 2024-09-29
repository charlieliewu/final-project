import requests  # Import requests module to send HTTP POST request

def emotion_detector(text_to_analyze):
    # Define the URL and headers
    url = 'https://sn-watson-emotion.labs.skills.network/v1/watson.runtime.nlp.v1/NlpService/EmotionPredict'
    headers = {"grpc-metadata-mm-model-id": "emotion_aggregated-workflow_lang_en_stock"}
    
    # Define the input JSON payload
    input_json = {
        "raw_document": {
            "text": text_to_analyze
        }
    }
    
    # Send the POST request to the Watson NLP EmotionPredict function
    response = requests.post(url, json=input_json, headers=headers)
    
    # Check if the request was successful
    if response.status_code == 200:
        return response.json().get("text")  # Extract the 'text' attribute from the response
    else:
        # Handle the error response
        return f"Error: {response.status_code}, {response.text}"

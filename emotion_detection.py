import requests
import json

# Emotion Detection Function        
def emotion_detector(text_to_analyze):  
    # Watson NLP Emotion Detection API URL
    url = 'https://sn-watson-emotion.labs.skills.network/v1/watson.runtime.nlp.v1/NlpService/EmotionPredict'  
    
    # requests
    headers = {
        "grpc-metadata-mm-model-id": "emotion_aggregated-workflow_lang_en_stock",    
        "Content-Type": "application/json"
    }
    
    # input json
    input_json = {
        "raw_document": {
            "text": text_to_analyze
        }
    }

    # Sending a POST request
    response = requests.post(url, headers=headers, data=json.dumps(input_json))    
    
    # Returns the text attribute in the response
    if response.status_code == 200:
        return response.json()  
    else:
        return {"error": "Failed to fetch emotion prediction"}  

# Test code
if __name__ == "__main__":
    test_text = "I like this new technology。"
    result = emotion_detector(test_text)  
    print(result)


from flask import Flask, request, jsonify, render_template
from EmotionDetection import emotion_detector

app = Flask(__name__)

@app.route('/emotionDetector', methods=['POST'])
def emotion_detection():
    # Extract the statement from the POST request
    data = request.json
    statement = data.get('statement', '')
    
    # Run the emotion detector function
    result = emotion_detector(statement)
    
    # Format the response
    response_string = (
        f"For the given statement, the system response

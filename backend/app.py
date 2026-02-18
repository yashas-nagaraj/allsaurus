from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
import os

app = Flask(__name__)
CORS(app)

def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv('DB_HOST'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )

@app.route('/api/health')
def health():
    return jsonify({"status": "Backend is running!"})

@app.route('/api/season/<season_id>')
def get_season(season_id):
    seasons = {
        "1": {"title": "Season 1: The Vanishing", "eps": ["Ep1: The Vanishing", "Ep2: The Weirdo"]},
        "2": {"title": "Season 2: The Mind Flayer", "eps": ["Ep1: MADMAX", "Ep2: Trick or Treat"]},
        "3": {"title": "Season 3: Starcourt", "eps": ["Ep1: Suzie?", "Ep2: Mall Rats"]},
        "4": {"title": "Season 4: Vecna", "eps": ["Ep1: Hellfire", "Ep2: Curse"]},
        "5": {"title": "Season 5: The Crawl", "eps": ["Ep1: The Crawl", "Ep2: TBD"]}
    }
    return jsonify(seasons.get(season_id, {"error": "Unknown Season"}))

@app.route('/api/questions', methods=['GET', 'POST'])
def handle_questions():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        if request.method == 'POST':
            data = request.json
            if 'question_id' in data: # It's an answer
                cursor.execute("INSERT INTO answers (question_id, answer_text) VALUES (%s, %s)", (data['question_id'], data['answer']))
            else: # It's a question
                cursor.execute("INSERT INTO questions (question_text) VALUES (%s)", (data['question'],))
            conn.commit()
            conn.close()
            return jsonify({"message": "Saved"})
        
        cursor.execute("SELECT q.id, q.question_text, a.answer_text FROM questions q LEFT JOIN answers a ON q.id = a.question_id")
        rows = cursor.fetchall()
        results = {}
        for row in rows:
            if row['id'] not in results: results[row['id']] = {'q': row['question_text'], 'a': []}
            if row['answer_text']: results[row['id']]['a'].append(row['answer_text'])
        conn.close()
        return jsonify(results)
    except Exception as e:
        return jsonify({"error": str(e)})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

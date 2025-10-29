from flask import Flask, render_template, request, redirect, url_for, session
import csv
import os
import random

app = Flask(__name__)
app.secret_key = 'your_secret_key'  # Needed for session tracking

# Directory paths
VIDEO_DIR = 'static/videos'
EXAMPLE_VIDEO_DIR = 'static/example_videos'
TEMP_DIR = 'temp'
MAIN_CSV = 'responses.csv'

# Ensure temp directory exists
os.makedirs(TEMP_DIR, exist_ok=True)

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        name = request.form['name'].strip()
        if not name:
            return render_template('index.html', error="Name is required")
        session['username'] = name
        session['ratings'] = []  # Reset any previous ratings
        session['video_index'] = 0  # Start from first video

        # Get all videos, shuffle, and store in session
        videos = [f for f in os.listdir(VIDEO_DIR) if f.endswith('.mp4')]
        random.shuffle(videos)
        session['videos'] = videos

        return redirect(url_for('preshow'))
    return render_template('index.html')

@app.route('/preshow')
def preshow():
    return render_template('preshow.html')

@app.route('/rate', methods=['GET'])
def rate():
    index = session.get('video_index', 0)
    videos = session.get('videos', [])

    if index >= len(videos):
        return render_template('thankyou.html')

    video_name = videos[index]
    total_videos = len(videos)
    current_index = index + 1  # 1-based for display
    percent_done = round((current_index / total_videos) * 100, 1)

    return render_template(
        'rate.html',
        video_name=video_name,
        current_index=index,
        total_videos=len(videos)
    )


@app.route('/submit', methods=['POST'])
def submit():
    video_id = request.form.get('video_id')
    rating = request.form.get('rating')
    username = session.get('username', 'anonymous')

    if rating is None:
        return "Error: Rating is required.", 400

    if 'ratings' not in session:
        session['ratings'] = []
    session['ratings'].append((username, video_id, rating))

    # Move to the next video
    session['video_index'] = session.get('video_index', 0) + 1

    # Save temporary file each time
    temp_file_path = os.path.join(TEMP_DIR, f"{username}.csv")
    with open(temp_file_path, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(session['ratings'])

    return redirect(url_for('rate'))

@app.route('/finalize', methods=['POST'])
def finalize():
    username = session.get('username', 'anonymous')
    temp_file_path = os.path.join(TEMP_DIR, f"{username}.csv")

    if os.path.exists(temp_file_path):
        with open(temp_file_path, 'r', newline='') as temp_f:
            temp_data = list(csv.reader(temp_f))
        with open(MAIN_CSV, 'a', newline='') as main_f:
            writer = csv.writer(main_f)
            writer.writerows(temp_data)
        os.remove(temp_file_path)

    return "Your responses have been saved. You may now close the tab."

if __name__ == '__main__':
    app.run(debug=True)

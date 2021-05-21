from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO, emit
from typing import Any, List
import psycopg2

app = Flask(__name__)
socketio = SocketIO(app)

t_host = "localhost"
t_port = "5432"
t_dbname = "dartinator"
t_user = "dartinator"
t_pw = "ithrow180s"
db_conn = psycopg2.connect(host=t_host, port=t_port, dbname=t_dbname,
        user=t_user, password=t_pw)
db_cursor = db_conn.cursor()

@app.route('/')
def root():
    return redirect(url_for('home'))

@app.route('/home')
def home():
    return render_template('index.html')

@app.route('/add-user')
def add_user():
    return render_template('add-user.html')

@app.route('/add-user', methods = ['POST'])
def add_user_post():
    player_name = request.form['nm']
    db_cursor.execute(f"SELECT add_player('{player_name}');");
    success = db_cursor.fetchone()[0] == 1
    db_conn.commit()
    return render_template('add-user.html', added = player_name,
            duplicate = not success)

@app.route('/view')
def view():
    return render_template('view.html')

@app.route('/new-game')
def new_game():
    db_cursor.execute('SELECT name FROM users;')
    return render_template('new-game.html', cursor = db_cursor)

@app.route('/new-game', methods = ['POST'])
def new_game_post():
    form = request.form.to_dict()
    gametype = form.pop('gametype')
    inmode = form.pop('inmode')
    outmode = form.pop('outmode')
    sets = int(form.pop('sets'))
    legs = int(form.pop('legs'))
    players = to_postgresql_array(form.keys())
    db_cursor.execute(f"""SELECT new_game('{players}', '{gametype}',
            '{inmode}', '{outmode}', {sets}, {legs});""")
    db_conn.commit()
    db_cursor.execute('select next_player_name();')
    npn = db_cursor.fetchone()[0]
    return render_template('running-game.html', next_player = npn)

@app.route('/running-game', methods = ['POST'])
def running_game_post():
    dart_fields: List[int] = request.get_json()
    dart_fields_arr = to_postgresql_array(dart_fields)
    db_cursor.execute(f"SELECT register_throw('{dart_fields_arr}');")
    db_conn.commit()
    db_cursor.execute('select next_player_name();')
    npn = db_cursor.fetchone()[0]
    return npn

@socketio.on('connect')
def on_connect():
    emit('after connect',  {'data':'Lets dance'})

def to_postgresql_array(arr: List[Any]) -> str:
    s: str = '{'
    for v in arr:
        s += f'"{v}",'
    s = s[:-1]
    s += '}'
    return s

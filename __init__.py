from flask import Flask, render_template, request, redirect, url_for
from typing import Any, List, Dict
import psycopg2

app = Flask(__name__)

t_host = "localhost"
t_port = "5432"
t_dbname = "dartinator"
t_user = "dartinator"
t_pw = "ithrow180s"
db_conn = psycopg2.connect(host=t_host, port=t_port, dbname=t_dbname,
        user=t_user, password=t_pw)
db_cursor = db_conn.cursor()

def to_postgresql_array(arr: List[Any]) -> str:
    s: str = '{'
    for v in arr:
        s += f'"{v}",'
    s = s[:-1]
    s += '}'
    return s

def get_user_count() -> int:
    db_cursor.execute("SELECT count(*) from players;")
    return db_cursor.fetchone()[0]
app.jinja_env.globals.update(get_user_count=get_user_count)

def foobar() -> None:
    print("FOOBAR")
app.jinja_env.globals.update(foobar=foobar)

@app.route('/')
def index():
    return redirect(url_for('home'))

@app.route('/home')
def home():
    return render_template('index.html')

@app.route('/view')
def show_view():
    return "This is the big screen!"

@app.route('/new')
def new_game():
    db_cursor.execute('SELECT name FROM users;')
    return render_template('new-game.html', cursor = db_cursor)

@app.route('/new', methods = ['POST'])
def new_game_submit():
    # print(request.form.to_dict())
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
    print(npn)
    return render_template('start-game.html', next_player = npn)

@app.route('/game-throw', methods = ['POST'])
def game_throw():
    dart_fields: List[int] = request.get_json()
    dart_fields_arr = to_postgresql_array(dart_fields)
    print(dart_fields_arr)
    db_cursor.execute(f"select register_throw('{dart_fields_arr}');")
    db_conn.commit()
    db_cursor.execute('select next_player_name();')
    npn = db_cursor.fetchone()[0]
    return npn

@app.route('/adduser', methods = ['POST'])
def add_user_submit():
    player_name = request.form['nm']
    db_cursor.execute(f"SELECT add_player('{player_name}');");
    success = db_cursor.fetchone()[0] == 1
    db_conn.commit()
    return render_template('add-user.html', added = player_name,
            duplicate = not success)

@app.route('/adduser')
def add_user():
    return render_template('add-user.html')

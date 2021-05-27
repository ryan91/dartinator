from flask import Flask, render_template, request, redirect, url_for
from flask_socketio import SocketIO, emit
from typing import Any, List
import os

database = None

def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    from . import db
    database = db.Database()
    socketio = SocketIO(app)
    app.config.from_mapping(SECRET_KEY='dev')
    if test_config is None:
        app.config.from_pyfile('config.py', silent=True)
    else:
        app.config.from_mapping(test_config)
    try:
        os.makedirs(app.instance_path)
    except OSError:
        pass

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
        c = database.get_cursor()
        c.execute(f"SELECT add_player('{player_name}');");
        success = c.fetchone()[0] == 1
        database.commit()
        return render_template('add-user.html', added = player_name,
                duplicate = not success)

    @app.route('/view')
    def view():
        c = database.get_cursor()
        c.execute("SELECT * FROM get_game_info_as_json;")
        if c.rowcount == 0:
            gi_str = "{}"
        else:
            gi_str = c.fetchone()[0]
        return render_template('view.html', game_info = gi_str)

    @app.route('/new-game')
    def new_game():
        c = database.get_cursor()
        c.execute('SELECT name FROM users;')
        return render_template('new-game.html', cursor = c)

    @app.route('/new-game', methods = ['POST'])
    def new_game_post():
        form = request.form.to_dict()
        gametype = form.pop('gametype')
        inmode = form.pop('inmode')
        outmode = form.pop('outmode')
        sets = int(form.pop('sets'))
        legs = int(form.pop('legs'))
        players = to_postgresql_array(form.keys())
        c = database.get_cursor()
        c.execute(f"""SELECT new_game('{players}', '{gametype}',
                '{inmode}', '{outmode}', {sets}, {legs});""")
        database.commit()
        c.execute('select next_player_name();')
        npn = c.fetchone()[0]
        return render_template('running-game.html', next_player = npn)

    @app.route('/running-game', methods = ['POST'])
    def running_game_post():
        dart_fields: List[int] = request.get_json()
        dart_fields_arr = to_postgresql_array(dart_fields)
        c = database.get_cursor()
        c.execute(f"SELECT register_throw('{dart_fields_arr}');")
        ret = c.fetchone()[0]
        if ret == 1: # checkout
            print('Checkout!')
        elif ret == 2 or ret == 3: # no score
            print('No score!')
        database.commit()
        c.execute('select next_player_name();')
        npn = c.fetchone()[0]
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

    return app

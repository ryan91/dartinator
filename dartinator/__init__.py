from flask import Flask, render_template, request, redirect, url_for, Markup, send_from_directory
from flask_socketio import SocketIO
from typing import Any, List
import os
import subprocess

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

    optimize_svg(app)

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

    @app.route('/running-game')
    def running_game():
        with app.open_resource('static/board.svg', mode='r') as svg:
            x = svg.read()
            return render_template('running-game.html', board = Markup(x))

    @app.route('/favicon.ico')
    def favicon():
        return send_from_directory(os.path.join(app.root_path, 'static'),
                'favicon.ico', mimetype='image/vnd.microsoft.icon')

    @app.route('/running-game', methods = ['POST'])
    def running_game_post():
        dart_fields: str = request.get_data().decode('utf-8')
        c = database.get_cursor()
        c.execute('select game_has_winner();')
        has_winnner = c.fetchone()[0]
        if has_winnner:
            return ""
        c.execute('select next_player();')
        current_player_id = c.fetchone()[0]
        c.execute(f'select name from users where id = {current_player_id};')
        current_player = c.fetchone()[0]
        c.execute(f"SELECT register_throw('{dart_fields}');")
        ret = c.fetchone()[0]
        print(ret)
        database.commit()
        c.execute('select next_player_name();')
        next_player = c.fetchone()[0]

        if ret == 0:
            c.execute(f"""select score from players where
            gameid = get_running_game() and playerid = {current_player_id};""")
            score = c.fetchone()[0]
            socketio.emit('register_throw',
                { 'player' : current_player
                , 'next_player' : next_player
                , 'score' : score
                })

        elif ret == 1:
            c.execute('select starting_player_name();')
            starting_player = c.fetchone()[0]
            c.execute(f"""select legs from players where playerid =
                {current_player_id};""")
            legs = c.fetchone()[0]
            c.execute('select score from n01options where gameid = get_running_game();')
            score = c.fetchone()[0]
            socketio.emit('game_shot_and_leg',
                { 'player' : current_player 
                , 'starting_player' : starting_player
                , 'legs' : legs
                , 'score' : score
                })

        elif ret == 2:
            c.execute('select starting_player_name();')
            starting_player = c.fetchone()[0]
            c.execute(f"""select sets from players where playerid =
                {current_player_id};""")
            sets = c.fetchone()[0]
            c.execute('select score from n01options where gameid = get_running_game();')
            score = c.fetchone()[0]
            socketio.emit('game_shot_and_set',
                { 'player' : current_player
                , 'starting_player' : starting_player
                , 'sets' : sets
                , 'score' : score
                })

        elif ret == 3:
            c.execute(f"""select sets from players where playerid =
                {current_player_id};""")
            sets = c.fetchone()[0]
            socketio.emit('game_shot_and_match',
                { 'player' : current_player
                , 'sets' : sets
                })

        elif ret == 4:
            print("No score")
            socketio.emit('no_score',
                { 'player' : current_player
                , 'next_player' : next_player
                })

        return ""

    def to_postgresql_array(arr: List[Any]) -> str:
        s: str = '{'
        for v in arr:
            s += f'"{v}",'
        s = s[:-1]
        s += '}'
        return s

    return app

def optimize_svg(app: Flask) -> None:
    in_svg = os.path.join(app.root_path, 'resources/board.svg')
    out_svg = os.path.join(app.root_path, 'static/board.svg')
    subprocess.run(['svgo', '-i', in_svg, '-o', out_svg])


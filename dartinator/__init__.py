from flask import Flask, render_template, request, redirect, url_for, Markup, send_from_directory
from flask_socketio import SocketIO
from typing import KeysView
import os

database = None

def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    from . import db
    from . import svg_opt
    in_svg = os.path.join(app.root_path, 'resources/board.svg')
    out_svg = os.path.join(app.root_path, 'static/board.svg')
    svgo = svg_opt.SvgOptimizer(in_svg, out_svg)
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

    svgo.optimize()

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
        from . import delivery
        dart_fields: str = request.get_data().decode('utf-8')
        c = database.get_cursor()
        if db.exec_single(c, 'select game_has_winner();'):
            return ""

        deliverer = delivery.Delivery(c)
        c.execute(f"SELECT register_throw('{dart_fields}');")
        ret = c.fetchone()[0]
        database.commit()
        emit_str: str = ''

        if ret == 0:
            deliverer.add_keys(['next_player', 'player_score'])
            emit_str = 'register_throw'

        elif ret == 1:
            deliverer.add_keys(['starting_player', 'legs', 'game_score',
                'played_legs'])
            emit_str = 'game_shot_and_leg'

        elif ret == 2:
            deliverer.add_keys(['starting_player', 'sets', 'game_score',
                'played_sets'])
            emit_str = 'game_shot_and_set'

        elif ret == 3:
            deliverer.add_key('sets')
            emit_str = 'game_shot_and_match'

        elif ret == 4:
            deliverer.add_key('next_player')
            emit_str = 'no_score'

        socketio.emit(emit_str, deliverer.execute())

        return ""

    def to_postgresql_array(arr: KeysView[str]) -> str:
        s: str = '{'
        for v in arr:
            s += f'"{v}",'
        s = s[:-1]
        s += '}'
        return s

    return app

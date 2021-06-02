from psycopg2._psycopg import cursor
from . import db
from typing import Any, Dict, List, Set

class Delivery():
    queries : Dict[str, str] = {
        'next_player': 'select next_player_name();',
        'player_score':
            """select score from players where gameid = get_running_game() and
            playerid = {};""",
        'starting_player': 'select starting_player_name();',
        'legs' : 'select legs from players where playerid = {};',
        'sets' : 'select sets from players where playerid = {};',
        'game_score' :
            """select score from n01options where gameid =
            get_running_game();""",
        'played_legs' : 'select * from get_played_legs;',
        'played_sets' : 'select * from get_played_sets;'
        }

    def __init__(self, c: cursor):
        self.keys: Set[str] = set()
        self.cur = c
        self.current_player_id = db.exec_single(c, 'select next_player();')
        self.current_player = db.exec_single(c,
            f'select name from users where id = {self.current_player_id};')

    def add_key(self, key: str):
        self.keys.add(key)

    def add_keys(self, keys: List[str]):
        for k in keys:
            self.add_key(k)

    def execute(self) -> Dict[str, Any]:
        d: Dict[str, Any] = {
            'player' : self.current_player
        }
        if self.keys.__contains__('next_player'):
            d['next_player'] = db.exec_single(self.cur,
                self.queries['next_player'])
        
        if self.keys.__contains__('player_score'):
            d['score'] = db.exec_single(self.cur, self.queries['player_score']
                .format(self.current_player_id))

        if self.keys.__contains__('starting_player'):
            d['starting_player'] = db.exec_single(self.cur,
                self.queries['starting_player'])

        if self.keys.__contains__('legs'):
            foo =self.queries['legs'].format(self.current_player_id)
            print(foo)
            d['legs'] = db.exec_single(self.cur, foo
                )

        if self.keys.__contains__('sets'):
            d['sets'] = db.exec_single(self.cur,
                self.queries['sets'].format(self.current_player_id))

        if self.keys.__contains__('game_score'):
            d['score'] = db.exec_single(self.cur,
                self.queries['game_score'].format(self.current_player_id))

        if self.keys.__contains__('played_legs'):
            d['total_legs'] = db.exec_single(self.cur,
                self.queries['played_legs'].format(self.current_player_id))

        if self.keys.__contains__('played_sets'):
            d['total_sets'] = db.exec_single(self.cur,
                self.queries['played_sets'].format(self.current_player_id))

        return d

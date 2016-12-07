// for phoenix_html support, including form and button helpers
// copy the following scripts into your javascript bundle:
// * https://raw.githubusercontent.com/phoenixframework/phoenix_html/v2.3.0/priv/static/phoenix_html.js

var PokerBoy = (function () {
  var socket,
  game_uuid,
  game_password,
  game;
  
  return {
    init: init,
    create_game: create_game
  };

  function init(){
    socket = new Phoenix.Socket('/socket');
    socket.logger = (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) };
    socket.connect();
  }

  function create_game(game_name, user_name){
    return new Promise(function(resolve, reject){
      var channel = socket.channel("game:lobby")
      channel.join()
        .receive("error", reason => reject(reason) );

      channel.push('create', {name: game_name});
      channel.on('created', game => {
        game_uuid = game.uuid;
        game_password = game.password;
        channel.leave();
        resolve();
      });
    })
    .then(function(){
      return new Game(game_uuid, user_name);
    });
  }

  function Game(game_uuid, username){
    var self = this, game_state = {};

    this.become_admin = become_admin;
    this.user_promote = user_promote;
    this.toggle_playing = toggle_playing;
    this.reveal = reveal;
    this.reset = reset;
    this.vote = vote;
    this.state = game_state;

    //runs on new to return promise which resovles with game object
    return new Promise(function(resolve, reject){
      game = socket.channel("game:"+game_uuid, {name: username});

      game.join()
        .receive("error", reason => reject(reason) );

      game.on("game_update", state => update(state.state) );

      var intervalCount = 0;
      var interval = setInterval(function(){
        if(game.state == "joined"){
          clearInterval(interval);
          resolve(self);
        }
        else if(intervalCount++ > 100){
          clearInterval(interval);
          reject("failed to connect to game");
        }
      }, 10);
    });

    function vote(vote){
      game.push('user_vote', {vote: vote});
    }

    function become_admin(password){
      game.push('become_admin', {password: password || game_password});
    }

    function user_promote(user_name){
      game.push('user_promote', {user: user_name});
    }

    function toggle_playing(user_name){
      game.push('toggle_playing', {user: user_name});
    }

    function reveal(){
      game.push('reveal', {});
    }

    function reset(){
      game.push('reset', {});
    }

    function update(state){
        mergeObject(game_state, state);
    }

    function mergeObject(obj1, obj2) {
      for (var attrname in obj2) {
        if (obj2.hasOwnProperty(attrname)) {
          obj1[attrname] = obj2[attrname];
        }
      }
      return obj1;
    }
  }
})();

PokerBoy.init();
PokerBoy.create_game('foo', 'lucas').then(function(game){ window.game = game; });
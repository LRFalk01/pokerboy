'use strict';

pPoker.constant('routes', {
    routes: [
        {
            name: 'base',
            url: '/',
            controller: 'BaseController',
            templateUrl: '/app/base/layout.html'
        },
        {
            name: 'game',
            parent: 'base',
            url: 'game/{gameId}',
            templateUrl: '/app/game/game.html',
        },
        {
            name: 'create',
            parent: 'base',
            url: 'create',
            templateUrl: '/app/create/create.html',
        }
    ]
});

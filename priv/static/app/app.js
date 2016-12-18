'use strict';

// Declare app level module which depends on filters, and services
var pPoker = angular.module('pPoker', ['ui.router', 'ui.validate', 'cgBusy', 'ui.bootstrap'])
    .config([
        '$urlRouterProvider', '$stateProvider', 'routes', function($urlRouterProvider, $stateProvider, routes) {
            //make urls case insensitive
            $urlRouterProvider.rule(function($injector, $location) {
                //what this function returns will be set as the $location.url
                var path = $location.path(), normalized = path.toLowerCase();
                if (path != normalized) {
                    //instead of returning a new url string, I'll just change the $location.path directly so 
                    //I don't have to worry about constructing a new url string and so a new state change is not triggered
                    $location.replace().path(normalized);
                }
                // because we've returned nothing, no state change occurs
            });

            $urlRouterProvider.otherwise('/create');
            var allRoutes = routes.routes;
            for (var i in allRoutes) {
                var route = allRoutes[i];
                $stateProvider.state(route);
            }
        }
    ]);

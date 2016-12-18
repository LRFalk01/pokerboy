'use strict';

pPoker.controller('CreateController',
    ['$scope', '$state', 'PokerBoyService',
    function LoginController($scope, $state, PokerBoyService) {
        var vm = this;

        vm.submitForm = submitForm;

        Init();
        ///////////////////////////////////
        function Init() {
        };

        function submitForm(form){
            PokerBoyService.Create(vm.Game, vm.Name)
            .then(function(game){
                $state.go('game', {gameId: game.id});
            });
        }
    }]
);
var myApp = angular.module("myApp", ['ngAnimate', 'ngTouch']);

myApp.controller("myCtrl", [ '$scope', function($scope, audio) {
    $scope.archives = archives;
    $scope.current_tab = 'archives'; // 初期タブ
    $scope.changeTab = function (tab) {
       $scope.current_tab = tab;
    }

    $scope.playlist = [];
    $scope.playlist_count = 0;
    $scope.current_url = '';

    $scope.selectArchive = function (archive) {
        if ($scope.playlist.length > 0) {
            console.log('current :' +  $scope.playlist[0].url);
            $scope.current_url = $scope.playlist[0].url;
        }

        if (archive.selected) {
            $scope.removeArchive(archive);
        } else {
            $scope.addAchive(archive);
        }
    }

    $scope.addAchive = function (archive) {
        console.log('add');
        archive.selected = true;
        $scope.playlist.push(archive);
        $scope.checkPlaylist();
    }

    $scope.removeArchive = function (archive) {
        console.log('remove');
        archive.selected = false;
        $scope.playlist = $scope.playlist.filter(function (item, index) {
            if (item.uuid != archive.uuid) return item;
        });
        $scope.checkPlaylist();
    }
    $scope.clickPlaylistArchive = function (archive, loop_index) {
        if (loop_index == 0) {
            if ($scope.audio.paused) {
                $scope.audio.play();
                archive.played = true;
            } else {
                $scope.audio.pause();
                archive.played = false;
            }
        } else {
            $scope.removeArchive(archive);
        }
    }

    $scope.checkPlaylist = function() {
        //Playlistの1番目が変わるとき
        if ($scope.playlist.length > 0 && $scope.current_url != $scope.playlist[0].url) {
            $scope.playArchive($scope.playlist[0]);

        // Playlistが無い時は初期化する
        } else if ($scope.playlist.length == 0) {
            console.log('init');
            $scope.audio.pause();
            $scope.audio.currentTime = 0;
            $("#audio source").remove();
            $scope.audio.load();
        }
    }

    $scope.playArchive = function (archive) {
        console.log(archive.url);
        $scope.audio = document.getElementById("audio");
        $("#audio source").remove();
        $("#audio").prepend("<source src=\"" + archive.url + "\" type=\"audio/mpeg\">");
        $scope.audio.load();
        $scope.audio.play();
        archive.played = true;
        console.log('played');

        $scope.audio.addEventListener('ended', function(){
            console.log('on ended');
            $scope.$apply($scope.removeArchive($scope.playlist.shift()));
        });
    }
}]);

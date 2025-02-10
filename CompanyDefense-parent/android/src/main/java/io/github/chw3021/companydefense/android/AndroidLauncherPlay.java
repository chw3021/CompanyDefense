package io.github.chw3021.companydefense.android;

import android.os.Bundle;
import android.util.Log;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.backends.android.AndroidApplication;
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration;
import com.google.android.gms.games.PlayGames;
import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.PlayGamesAuthProvider;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.platform.GoogleSignInHandler;

/** Launches the Android application. */
/*
public class AndroidLauncherPlay extends AndroidApplication implements GoogleSignInHandler {
    private FirebaseAuth firebaseAuth;
    private FirebaseCallback<UserDto> currentCallback; // 로그인 결과 전달용 콜백

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Firebase 초기화
        FirebaseApp.initializeApp(this);
        firebaseAuth = FirebaseAuth.getInstance();
        FirebaseService firebaseService = new FirebaseServiceImpl();

        // Android 애플리케이션 초기화
        AndroidApplicationConfiguration config = new AndroidApplicationConfiguration();
        initialize(new Main(firebaseService, this), config);

        // 자동 로그인 시도
        autoSignIn();
    }

    private void autoSignIn() {
        PlayGames.getGamesSignInClient(this).signIn()
            .addOnCompleteListener(task -> {
                if (task.isSuccessful()) {
                    // 로그인 성공 시 Firebase 연동
                    getPlayerInfo();
                } else {
                    Log.e("GPGS", "자동 로그인 실패");
                }
            });
    }

    @Override
    public void signIn(FirebaseCallback<UserDto> callback) {
        this.currentCallback = callback;
        PlayGames.getGamesSignInClient(this).signIn()
            .addOnCompleteListener(task -> {
                if (task.isSuccessful()) {
                    getPlayerInfo();
                } else {
                    if (currentCallback != null) {
                        currentCallback.onFailure(new Exception("Google Play Games 로그인 실패"));
                    }
                }
            });
    }

    private void getPlayerInfo() {
        PlayGames.getPlayersClient(this).getCurrentPlayer()
            .addOnSuccessListener(player -> {
                String playerId = player.getPlayerId();
                String displayName = player.getDisplayName();

                // Firebase 인증 처리
                firebaseAuthWithPlayGames(playerId, displayName);
            })
            .addOnFailureListener(e -> {
                Log.e("GPGS", "플레이어 정보 가져오기 실패", e);
                if (currentCallback != null) {
                    currentCallback.onFailure(e);
                }
            });
    }

    private void firebaseAuthWithPlayGames(String playerId, String displayName) {
        AuthCredential credential = PlayGamesAuthProvider.getCredential(playerId);
        firebaseAuth.signInWithCredential(credential)
            .addOnCompleteListener(this, task -> {
                if (task.isSuccessful()) {
                    FirebaseUser user = firebaseAuth.getCurrentUser();
                    if (user != null) {
                        UserDto userDto = new UserDto();
                        userDto.setUserId(user.getUid());
                        userDto.setUserName(displayName);
                        userDto.setLoginProvider("google_play_games");

                        // 로그인 정보 저장
                        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                        prefs.putString("loginProvider", "google_play_games");
                        prefs.putString("userId", user.getUid());
                        prefs.putString("userName", userDto.getUserName());
                        prefs.flush();

                        if (currentCallback != null) {
                            currentCallback.onSuccess(userDto);
                        }
                    }
                } else {
                    if (currentCallback != null) {
                        currentCallback.onFailure(task.getException());
                    }
                }
            });
    }
}
*/


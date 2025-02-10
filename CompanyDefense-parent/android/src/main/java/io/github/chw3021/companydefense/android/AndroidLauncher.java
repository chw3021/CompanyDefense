package io.github.chw3021.companydefense.android;

import android.content.Intent;
import android.os.Bundle;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.backends.android.AndroidApplication;
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GoogleAuthProvider;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.R;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.platform.GoogleSignInHandler;

public class AndroidLauncher extends AndroidApplication implements GoogleSignInHandler {
    private GoogleSignInClient googleSignInClient;
    private FirebaseAuth firebaseAuth;
    private static final int RC_SIGN_IN = 9001;
    private FirebaseCallback<UserDto> currentCallback; // 로그인 결과 전달용 콜백

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Firebase 초기화
        FirebaseApp.initializeApp(this);
        firebaseAuth = FirebaseAuth.getInstance();
        FirebaseService firebaseService = new FirebaseServiceImpl();

        // Google Sign-In 옵션 설정 (Play Games가 아닌 기본 로그인으로 설정)
        GoogleSignInOptions gso = new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(getString(R.string.default_web_client_id)) // Firebase 연동을 위한 ID 토큰 요청
            .requestEmail()
            .build();
        googleSignInClient = GoogleSignIn.getClient(this, gso);

        // Android 애플리케이션 초기화
        AndroidApplicationConfiguration config = new AndroidApplicationConfiguration();
        initialize(new Main(firebaseService, this), config);
    }

    @Override
    public void signIn(FirebaseCallback<UserDto> callback) {
        this.currentCallback = callback;

        // 이미 로그인된 구글 계정이 있으면 바로 처리
        GoogleSignInAccount lastSignedInAccount = GoogleSignIn.getLastSignedInAccount(this);
        if (lastSignedInAccount != null) {
            firebaseAuthWithGoogle(lastSignedInAccount.getIdToken());
        } else {
            // 로그인된 계정이 없으면 로그인 창을 띄움
            Intent signInIntent = googleSignInClient.getSignInIntent();
            startActivityForResult(signInIntent, RC_SIGN_IN);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == RC_SIGN_IN) {
            Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
            try {
                GoogleSignInAccount account = task.getResult(ApiException.class);
                firebaseAuthWithGoogle(account.getIdToken());
            } catch (ApiException e) {
                if (currentCallback != null) {
                    currentCallback.onFailure(e);
                }
            }
        }
    }

    private void firebaseAuthWithGoogle(String idToken) {
        AuthCredential credential = GoogleAuthProvider.getCredential(idToken, null);
        firebaseAuth.signInWithCredential(credential)
            .addOnCompleteListener(this, task -> {
                if (task.isSuccessful()) {
                    FirebaseUser user = firebaseAuth.getCurrentUser();
                    if (user != null) {
                        UserDto userDto = new UserDto();
                        userDto.setUserId(user.getUid());
                        userDto.setUserName(user.getDisplayName() != null ? user.getDisplayName() : "Unknown User");
                        userDto.setLoginProvider("google");

                        // 로그인 성공 시 SharedPreferences 저장
                        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                        prefs.putString("loginProvider", "google");
                        prefs.putString("userId", user.getUid());
                        prefs.putString("userName", userDto.getUserName());
                        prefs.flush();

                        if (currentCallback != null) {
                            currentCallback.onSuccess(userDto);
                        }
                    } else {
                        if (currentCallback != null) {
                            currentCallback.onFailure(new Exception("Firebase user is null after sign-in"));
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

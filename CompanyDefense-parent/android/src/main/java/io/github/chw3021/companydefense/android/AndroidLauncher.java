package io.github.chw3021.companydefense.android;

import android.content.Intent;
import android.os.Bundle;

import com.badlogic.gdx.backends.android.AndroidApplication;
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration;
import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.auth.GoogleSignInAccount;
import com.google.firebase.auth.GoogleSignInClient;
import com.google.firebase.auth.Task;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.platform.GoogleSignInHandler;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.dto.UserDto;

/** Launches the Android application. */
public class AndroidLauncher extends AndroidApplication implements GoogleSignInHandler {
    private GoogleSignInClient googleSignInClient;
    private static final int RC_SIGN_IN = 9001;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Firebase 초기화
        FirebaseApp.initializeApp(this);
        FirebaseService firebaseService = new AndroidFirebaseService();

        // Google Sign-In 클라이언트 설정
        GoogleSignInOptions gso = new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestIdToken(getString(R.string.default_web_client_id)) // Firebase Web Client ID 필요
                .requestEmail()
                .build();
        googleSignInClient = GoogleSignIn.getClient(this, gso);

        // Android 애플리케이션 초기화
        AndroidApplicationConfiguration configuration = new AndroidApplicationConfiguration();
        configuration.useImmersiveMode = true;
        initialize(new Main(firebaseService, this), configuration);  // FirebaseService와 GoogleSignInHandler 전달

        // LoginScreen에 GoogleSignInHandler 전달
        setScreen(new LoginScreen(game, this)); // GoogleSignInHandler 전달
    }

    @Override
    public void signIn(FirebaseCallback<UserDto> callback) {
        Intent signInIntent = googleSignInClient.getSignInIntent();
        startActivityForResult(signInIntent, RC_SIGN_IN);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == RC_SIGN_IN) {
            Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
            try {
                GoogleSignInAccount account = task.getResult(ApiException.class);
                firebaseAuthWithGoogle(account.getIdToken(), callback);
            } catch (ApiException e) {
                callback.onFailure(e);
            }
        }
    }

    private void firebaseAuthWithGoogle(String idToken, FirebaseCallback<UserDto> callback) {
        FirebaseAuth auth = FirebaseAuth.getInstance();
        AuthCredential credential = GoogleAuthProvider.getCredential(idToken, null);
        auth.signInWithCredential(credential)
                .addOnCompleteListener(this, task -> {
                    if (task.isSuccessful()) {
                        FirebaseUser user = auth.getCurrentUser();
                        if (user != null) {
                            UserDto userDto = new UserDto();
                            userDto.setUserId(user.getUid());
                            userDto.setUserName(user.getDisplayName() != null ? user.getDisplayName() : "Unknown User");
                            userDto.setLoginProvider("google");

                            callback.onSuccess(userDto);
                        } else {
                            callback.onFailure(new Exception("Firebase user is null after sign-in"));
                        }
                    } else {
                        callback.onFailure(task.getException());
                    }
                });
    }
}

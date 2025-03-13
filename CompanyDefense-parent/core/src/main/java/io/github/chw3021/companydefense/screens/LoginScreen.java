package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.Sprite;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.ScreenUtils;
import com.badlogic.gdx.utils.viewport.ScreenViewport;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.firebase.TokenManager;
import io.github.chw3021.companydefense.platform.GoogleSignInHandler;
import okhttp3.OkHttpClient;

public class LoginScreen implements Screen, LoadingListener {
    private final Main game;
    private final FirebaseServiceImpl firebaseService;

    private OrthographicCamera camera;
    private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private final OkHttpClient client = new OkHttpClient();

    private Texture backgroundTexture;
    private Sprite backgroundSprite;

    private LoadingScreenManager loadingScreenManager;

    private GoogleSignInHandler googleSignInHandler;

    private final TokenManager tokenManager = TokenManager.getInstance();
    @Override
    public void onLoadingStart() {
        Gdx.app.postRunnable(() -> loadingScreenManager.showLoadingScreen());
    }

    @Override
    public void onLoadingEnd() {
        Gdx.app.postRunnable(() -> loadingScreenManager.hideLoadingScreen());
    }



    public LoginScreen(Main game, GoogleSignInHandler googleSignInHandler) {
        this.game = game;
        this.firebaseService = (FirebaseServiceImpl) game.getFirebaseService();
        this.googleSignInHandler = googleSignInHandler; // 전달된 googleSignInHandler 사용

        batch = new SpriteBatch();
        firebaseService.addLoadingListener(this);
        camera = new OrthographicCamera();

        stage = new Stage(new ScreenViewport(camera));
        skin = new Skin(Gdx.files.internal("ui/companyskin.json")); // UI 스킨 파일 (uiskin.json 필요)
        Gdx.input.setInputProcessor(stage);
        backgroundTexture = new Texture(Gdx.files.internal("menu/menu_background.jpg")); // 배경 이미지 경로
        backgroundSprite = new Sprite(backgroundTexture);
        backgroundSprite.setSize(Gdx.graphics.getWidth(), Gdx.graphics.getHeight()); // 화면 크기에 맞게 배경 사이즈 조정

        this.loadingScreenManager = new LoadingScreenManager(stage);

        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String loginProvider = prefs.getString("loginProvider", null);
        if (loginProvider != null) {
            if (loginProvider.equals("guest")) {
                loginAsGuest();
            } else if (loginProvider.equals("google")) {
                loginAsGuest();
            }
            else{
                Gdx.app.log("Login", "Unknown login provider: " + loginProvider);
            }
            return;
        }
        createButtons();
    }

    private void createButtons() {
        float buttonWidth = Gdx.graphics.getWidth() * 0.7f;
        float buttonHeight = Gdx.graphics.getHeight() * 0.1f;
        float centerX = Gdx.graphics.getWidth() / 2f - buttonWidth / 2f;

        TextButton googleButton = new TextButton("Google Login", skin);
        googleButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.6f, buttonWidth, buttonHeight);
        googleButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                loginWithGooglePlay();
            }
        });
//
//        TextButton iosButton = new TextButton("iOS Login", skin);
//        iosButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.45f, buttonWidth, buttonHeight);
//        iosButton.addListener(new ClickListener() {
//            @Override
//            public void clicked(InputEvent event, float x, float y) {
//                loginWithIOS();
//            }
//        });
//
//        TextButton kakaoButton = new TextButton("Kakao Login", skin);
//        kakaoButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.3f, buttonWidth, buttonHeight);
//        kakaoButton.addListener(new ClickListener() {
//            @Override
//            public void clicked(InputEvent event, float x, float y) {
//                loginWithKakao();
//            }
//        });

        TextButton guestButton = new TextButton("Guest Login", skin);
        guestButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.15f, buttonWidth, buttonHeight);
        guestButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                loginAsGuest();
            }
        });

        stage.addActor(googleButton);
        stage.addActor(guestButton);
    }

    private void loginWithIOS() {
        // iOS 로그인 처리 로직 (테스트 중에는 빈 구현)
        Gdx.app.log("Login", "iOS Login selected");
    }

    private void loginWithKakao() {
        // Kakao 로그인 처리 로직 (테스트 중에는 빈 구현)
        Gdx.app.log("Login", "Kakao Login selected");
    }
    private void loginAsGuest() {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String existingUserId = prefs.getString("userId", null);
        String storedIdToken = prefs.getString("idToken", null); // 🔹 저장된 idToken 가져오기

        if (existingUserId != null && storedIdToken != null) {
            tokenManager.setIdToken(storedIdToken); // 🔹 idToken 설정
            firebaseService.fetchData("users/" + existingUserId, UserDto.class, new FirebaseCallback<UserDto>() {
                @Override
                public void onSuccess(UserDto user) {
                    Gdx.app.log("Login", "Existing guest user loaded: " + user.getUserId());
                    Gdx.app.postRunnable(() -> {
                        game.setScreen(new MainViewScreen(game));
                    });
                }

                @Override
                public void onFailure(Exception e) {
                    Gdx.app.error("Login", "Failed to load existing guest user, re-authenticating...");
                    signInAgain(); // 🔹 idToken이 만료된 경우 다시 로그인 시도
                }
            });
        } else {
            // 🔹 Firebase Auth 익명 로그인 사용
            signInAgain();
        }
    }

    private void signInAgain() {
        firebaseService.signInAnonymously(new FirebaseCallback<String>() {
            @Override
            public void onSuccess(String idToken) {
                tokenManager.setIdToken(idToken);
                Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                prefs.putString("idToken", idToken); // 🔹 idToken 저장
                prefs.flush();

                if (prefs.getString("userId", null) == null) {
                    createNewGuest();
                } else {
                    loginAsGuest(); // 🔹 기존 계정 불러오기 재시도
                }
            }

            @Override
            public void onFailure(Exception e) {
                Gdx.app.error("Login", "Guest login failed", e);
            }
        });
    }

    private void createNewGuest() {
        UserDto user = new UserDto();
        user.setUserId("guest_" + System.currentTimeMillis());
        user.setUserName("Guest");
        user.setLoginProvider("guest");

        firebaseService.saveData("users/" + user.getUserId(), user, new FirebaseCallback<Void>() {
            @Override
            public void onSuccess(Void result) {
                Gdx.app.log("Login", "Guest login successful: " + user.getUserId());
                Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                prefs.putString("loginProvider", "guest");
                prefs.putString("userId", user.getUserId());
                prefs.flush();

                Gdx.app.postRunnable(() -> {
                    game.setScreen(new MainViewScreen(game)); // 메인 메뉴로 이동
                });
            }

            @Override
            public void onFailure(Exception e) {
                Gdx.app.error("Login", "Guest login failed", e);
            }
        });
    }
    private void loginWithGooglePlay() {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String existingUserId = prefs.getString("userId", null);
        String storedIdToken = prefs.getString("idToken", null); // Google 로그인에도 저장된 토큰 확인
    
        if (existingUserId != null && storedIdToken != null) {
            // 기존 유저 ID와 토큰이 있으면 토큰 설정 후 로그인
            firebaseService.setIdToken(storedIdToken);
            
            // 토큰 유효성 검증을 위해 유저 데이터 요청
            firebaseService.fetchData("users/" + existingUserId, UserDto.class, new FirebaseCallback<UserDto>() {
                @Override
                public void onSuccess(UserDto user) {
                    Gdx.app.log("Login", "Existing google user loaded: " + user.getUserId());
                    Gdx.app.postRunnable(() -> {
                        game.setScreen(new MainViewScreen(game));
                    });
                }
    
                @Override
                public void onFailure(Exception e) {
                    Gdx.app.error("Login", "Failed to load existing google user or token expired", e);
                    // 토큰이 만료되었거나 문제가 있을 경우 다시 로그인
                    initiateGoogleSignIn();
                }
            });
        } else {
            // 사용자 정보나 토큰이 없으면 새로 로그인
            initiateGoogleSignIn();
        }
    }
    
    private void initiateGoogleSignIn() {
        if (googleSignInHandler != null) {
            googleSignInHandler.signIn(new FirebaseCallback<UserDto>() {
                @Override
                public void onSuccess(UserDto user) {
                    Gdx.app.log("Login", "Google Login Success: " + user.getUserId());
    
                    // ID 토큰을 FirebaseService에 설정
                    if (user.getIdToken() != null) {
                        firebaseService.setIdToken(user.getIdToken());
                        
                        // ID 토큰을 preferences에 저장 (중요!)
                        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                        prefs.putString("idToken", user.getIdToken());
                        prefs.flush();
                    }
    
                    saveNewGoogleUser(user);
                }
    
                @Override
                public void onFailure(Exception e) {
                    Gdx.app.error("Login", "Google Login Failed", e);
                }
            });
        }
    }
    private void saveNewGoogleUser(UserDto googleUser) {
        googleUser.setLoginProvider("google");
    
        firebaseService.saveData("users/" + googleUser.getUserId(), googleUser, new FirebaseCallback<Void>() {
            @Override
            public void onSuccess(Void result) {
                Gdx.app.log("Login", "Google login successful: " + googleUser.getUserId());
    
                Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                prefs.putString("loginProvider", "google");
                prefs.putString("userId", googleUser.getUserId());
                prefs.putString("userName", googleUser.getUserName());
                // idToken이 이미 앞에서 저장되었는지 확인하고, 없으면 다시 저장
                if (prefs.getString("idToken", null) == null && googleUser.getIdToken() != null) {
                    prefs.putString("idToken", googleUser.getIdToken());
                }
                prefs.flush();
    
                Gdx.app.postRunnable(() -> {
                    game.setScreen(new MainViewScreen(game));
                });
            }
    
            @Override
            public void onFailure(Exception e) {
                Gdx.app.error("Login", "Google login failed", e);
            }
        });
    }

    @Override
    public void show() {}

    @Override
    public void render(float delta) {
        ScreenUtils.clear(0, 0, 0, 1);
        camera.update();


        batch.setProjectionMatrix(camera.combined);
        batch.begin();

        // 배경을 화면에 맞게 그리기
        backgroundSprite.draw(batch);

        batch.end();

        stage.act(Gdx.graphics.getDeltaTime());
        stage.draw();
    }

    @Override
    public void resize(int width, int height) {
        stage.getViewport().update(width, height, true);
    }

    @Override
    public void pause() {}

    @Override
    public void resume() {}

    @Override
    public void hide() {}

    @Override
    public void dispose() {
        stage.dispose();
        skin.dispose();
    }

}

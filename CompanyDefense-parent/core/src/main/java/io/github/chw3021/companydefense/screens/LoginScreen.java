package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.OrthographicCamera;
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

public class LoginScreen implements Screen, LoadingListener {
    private final Main game;
    private final FirebaseServiceImpl firebaseService;

    private OrthographicCamera camera;
    private Stage stage;
    private Skin skin;


    private LoadingScreenManager loadingScreenManager;

    @Override
    public void onLoadingStart() {
        Gdx.app.postRunnable(() -> loadingScreenManager.testLoadingScreen());
    }

    @Override
    public void onLoadingEnd() {
        Gdx.app.postRunnable(() -> loadingScreenManager.hideLoadingScreen());
    }
    
    
    
    public LoginScreen(Main game) {
        this.game = game;
        this.firebaseService = (FirebaseServiceImpl) game.getFirebaseService();        
        firebaseService.addLoadingListener(this);
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800);

        stage = new Stage(new ScreenViewport(camera));
        skin = new Skin(Gdx.files.internal("uiskin.json")); // UI 스킨 파일 (uiskin.json 필요)
        Gdx.input.setInputProcessor(stage);

        this.loadingScreenManager = new LoadingScreenManager(stage);

        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String loginProvider = prefs.getString("loginProvider", null);
        if (loginProvider != null) {
            // 로그인 상태가 존재할 경우 바로 메인 메뉴로 이동
            if (loginProvider.equals("guest")) {
            	loginAsGuest();
            }
            else if (loginProvider.equals("google")) {
            	loginAsGuest();
            }
            else if (loginProvider.equals("ios")) {
            	loginAsGuest();
            }
            else if (loginProvider.equals("kakao")) {
            	loginAsGuest();
            }
            return;
        }
        createButtons();
    }

    private void createButtons() {
        float buttonWidth = Gdx.graphics.getWidth() * 0.7f;
        float buttonHeight = Gdx.graphics.getHeight() * 0.1f;
        float centerX = Gdx.graphics.getWidth() / 2f - buttonWidth / 2f;

        TextButton googleButton = new TextButton("Google Play Store Login", skin);
        googleButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.6f, buttonWidth, buttonHeight);
        googleButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                loginWithGooglePlay();
            }
        });

        TextButton iosButton = new TextButton("iOS Login", skin);
        iosButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.45f, buttonWidth, buttonHeight);
        iosButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                loginWithIOS();
            }
        });

        TextButton kakaoButton = new TextButton("Kakao Login", skin);
        kakaoButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.3f, buttonWidth, buttonHeight);
        kakaoButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                loginWithKakao();
            }
        });

        TextButton guestButton = new TextButton("Guest Login", skin);
        guestButton.setBounds(centerX, Gdx.graphics.getHeight() * 0.15f, buttonWidth, buttonHeight);
        guestButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                loginAsGuest();
            }
        });

        stage.addActor(googleButton);
        stage.addActor(iosButton);
        stage.addActor(kakaoButton);
        stage.addActor(guestButton);
    }

    private void loginWithGooglePlay() {
        // Google Play 로그인 처리 로직 (테스트 중에는 빈 구현)
        Gdx.app.log("Login", "Google Play Store Login selected");
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
        if (existingUserId != null) {
            // 기존 유저 ID가 존재하면 데이터를 불러오기
            firebaseService.fetchData("users/" + existingUserId, UserDto.class, new FirebaseCallback<UserDto>() {
                @Override
                public void onSuccess(UserDto user) {
                    Gdx.app.log("Login", "Existing guest user loaded: " + user.getUserId());
                    Gdx.app.postRunnable(() -> {
                        game.setScreen(new MainViewScreen(game)); // 메인 메뉴로 이동
                    });
                }

                @Override
                public void onFailure(Exception e) {
                    Gdx.app.error("Login", "Failed to load existing guest user", e);
                }
            });
        } else {
            // 기존 유저 ID가 없으면 새로운 게스트 생성
            createNewGuest();
        }
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


    @Override
    public void show() {}

    @Override
    public void render(float delta) {
        ScreenUtils.clear(0, 0, 0, 1);
        camera.update();

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

package io.github.chw3021.companydefense.screens.equipmentscreens;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Scaling;
import com.badlogic.gdx.utils.viewport.ScreenViewport;
import com.google.gson.reflect.TypeToken;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.screens.LoadingScreenManager;
import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreen;
import io.github.chw3021.companydefense.screens.menu.MenuScreen;

import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
public class TowerScreen implements Screen, LoadingListener {
    private SpriteBatch batch;
    private Stage stage;
    private Skin skin;
    private Table table;
    private OrthographicCamera camera;

    private Game game;
    private UserDto userDto; // 현재 로그인된 사용자 정보
    private List<TowerDto> allTowers; // 모든 타워 종류
    private FirebaseServiceImpl firebaseService; // Firebase 연동


    private LoadingScreenManager loadingScreenManager;

    @Override
    public void onLoadingStart() {
        Gdx.app.postRunnable(() -> loadingScreenManager.showLoadingScreen());
    }

    @Override
    public void onLoadingEnd() {
        Gdx.app.postRunnable(() -> loadingScreenManager.hideLoadingScreen());
    }
    
    public TowerScreen(Game game) {
        this.game = game;
        this.firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        firebaseService.addLoadingListener(this);
        batch = new SpriteBatch();
        stage = new Stage(new ScreenViewport(), batch);

        // 카메라 초기화
        camera = new OrthographicCamera();
        camera.setToOrtho(false, 480, 800);
        camera.position.set(camera.viewportWidth / 2, camera.viewportHeight / 2, 0);
        
        this.loadingScreenManager = new LoadingScreenManager(stage);
    }

    @Override
    public void show() {
        // Stage 초기화
        stage = new Stage(new ScreenViewport(), batch);
        skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        Gdx.input.setInputProcessor(stage);

        // Firebase에서 데이터 로드
        loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
            @Override
            public void onSuccess(List<TowerDto> towers) {
                allTowers = towers;
                loadUserData(new FirebaseCallback<UserDto>() {
                    @Override
                    public void onSuccess(UserDto user) {
                        userDto = user;
                        initializeUI();
                    }

                    @Override
                    public void onFailure(Exception e) {
                        System.err.println("Fail to load userData: " + e.getMessage());
                    }
                });
            }

            @Override
            public void onFailure(Exception e) {
                System.err.println("Fail to load TowerData: " + e.getMessage());
            }
        });
    }
    private void loadAllTowers(FirebaseCallback<List<TowerDto>> callback) {
        // Firebase에서 모든 타워 데이터를 Map 형태로 가져오기
        firebaseService.fetchData("towers/", new TypeToken<Map<String, TowerDto>>() {}.getType(), new FirebaseCallback<Map<String, TowerDto>>() {
            @Override
            public void onSuccess(Map<String, TowerDto> towersMap) {
                // Map의 값들만 List로 변환하여 반환
                List<TowerDto> towersList = new ArrayList<>(towersMap.values());
                callback.onSuccess(towersList);
            }

            @Override
            public void onFailure(Exception e) {
                callback.onFailure(e);
            }
        });
    }

    private void loadUserData(FirebaseCallback<UserDto> callback) {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String userId = prefs.getString("userId", null);
        if (userId == null) {
            callback.onFailure(new Exception("login required"));
            return;
        }

        // Firebase에서 사용자 데이터 가져오기
        firebaseService.fetchData("users/" + userId, UserDto.class, new FirebaseCallback<UserDto>() {
            @Override
            public void onSuccess(UserDto fetchedUser) {
                if (fetchedUser == null || fetchedUser.getUserTowers() == null || fetchedUser.getUserTowers().isEmpty()) {
                    // 타워 데이터가 없을 경우 기본 타워 데이터 생성
                    loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
                        @Override
                        public void onSuccess(List<TowerDto> towers) {
                            // `AtomicReference`로 UserDto를 감싸기
                            AtomicReference<UserDto> userRef = new AtomicReference<>(fetchedUser);
                            if (userRef.get() == null) {
                                userRef.set(new UserDto());
                                userRef.get().setUserId(userId);
                            }

                            List<TowerOwnershipDto> defaultTowers = new ArrayList<>();
                            for (TowerDto tower : towers) {
                                defaultTowers.add(new TowerOwnershipDto(tower.getTowerId(), 1));
                            }

                            userRef.get().setUserTowers(defaultTowers);

                            // 생성된 기본 데이터를 Firebase에 저장
                            firebaseService.saveData("users/" + userId, userRef.get(), new FirebaseCallback<Void>() {
                                @Override
                                public void onSuccess(Void unused) {
                                    callback.onSuccess(userRef.get());
                                }

                                @Override
                                public void onFailure(Exception e) {
                                    callback.onFailure(e);
                                }
                            });
                        }

                        @Override
                        public void onFailure(Exception e) {
                            callback.onFailure(e);
                        }
                    });
                } else {
                    // 기존 사용자 데이터가 있을 경우, 데이터를 그대로 사용
                    callback.onSuccess(fetchedUser);
                }
            }

            @Override
            public void onFailure(Exception e) {
                callback.onFailure(e);
            }
        });
    }


    private void initializeUI() {
        // Table 레이아웃 설정
        table = new Table();
        table.setFillParent(true);
        stage.addActor(table);

        // 타워 데이터를 기반으로 그리드 생성
        for (TowerOwnershipDto towerOwnership : userDto.getUserTowers()) {
            TowerDto tower = findTowerById(towerOwnership.getTowerId());
            if (tower != null) {
                addTowerToGrid(tower, towerOwnership.getTowerLevel());
            }
        }
    }

    private TowerDto findTowerById(String towerId) {
        for (TowerDto tower : allTowers) {
            if (tower.getTowerId().equals(towerId)) {
                return tower;
            }
        }
        return null;
    }
    private void addTowerToGrid(TowerDto tower, int level) {
        Gdx.app.postRunnable(() -> {
            try {
                Table towerTable = new Table();

                // 타워 이미지 추가
                Image towerImage = new Image(new Texture(Gdx.files.internal(tower.getTowerImagePath())));
                towerImage.setScaling(Scaling.fit);

                // 타워 이름 추가
                Label nameLabel = new Label(tower.getTowerName(), skin);

                // 타워 레벨 추가
                Label levelLabel = new Label("레벨: " + level, skin);

                // 타워 정보 레이아웃에 추가
                towerTable.add(towerImage).size(80).row();
                towerTable.add(nameLabel).padTop(5).row();
                towerTable.add(levelLabel).padTop(5);

                // 그리드에 타워 추가
                table.add(towerTable).pad(10).size(100, 150); // 타워 버튼 크기와 간격 설정
                if (table.getChildren().size % 3 == 0) {
                    table.row(); // 3개마다 줄바꿈
                }

                // 타워 클릭 이벤트 추가
                towerImage.addListener(new ClickListener() {
                    @Override
                    public void clicked(InputEvent event, float x, float y) {
                        // 타워 클릭 시 동작 (예: 타워 상세 정보 표시)
                        System.out.println("타워 클릭: " + tower.getTowerName());
                    }
                });
            } catch (Exception e) {
                Gdx.app.error("TowerScreen", "Failed to add tower to grid: " + tower.getTowerImagePath(), e);
            }
        });
    }

    @Override
    public void render(float delta) {
        Gdx.gl.glClearColor(0.1f, 0.1f, 0.1f, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

        camera.update();
        stage.act(Math.min(Gdx.graphics.getDeltaTime(), 1 / 30f));
        stage.draw();
    }

    @Override
    public void resize(int width, int height) {
        stage.getViewport().update(width, height, true);
    }

    @Override
    public void hide() {
        stage.dispose();
    }

    @Override
    public void pause() {}

    @Override
    public void resume() {}

    @Override
    public void dispose() {
        batch.dispose();
    }
}

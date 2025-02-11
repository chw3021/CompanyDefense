package io.github.chw3021.companydefense.screens.equipmentscreens;

import java.util.List;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Dialog;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.ImageButton;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.Scaling;
import com.badlogic.gdx.utils.viewport.ScreenViewport;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.firebase.LoadingListener;
import io.github.chw3021.companydefense.screens.LoadingScreenManager;
public class TowerScreen implements Screen, LoadingListener {
    private Stage stage;
    private Skin skin;
    private Table table;
    private OrthographicCamera camera;

    private Game game;
    private UserDto userDto;
    private List<TowerDto> allTowers;
    private FirebaseServiceImpl firebaseService;

    private Label playerGoldLabel; // 플레이어 재화 표시용 라벨

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

        // 화면 크기 가져오기
        float screenWidth = Gdx.graphics.getWidth();
        float screenHeight = Gdx.graphics.getHeight();

        // 카메라 및 뷰포트 설정
        camera = new OrthographicCamera();

        stage = new Stage(new ScreenViewport(camera));
        skin = new Skin(Gdx.files.internal("ui/companyskin.json"));
        Gdx.input.setInputProcessor(stage);

        firebaseService.addLoadingListener(this);
        this.loadingScreenManager = new LoadingScreenManager(stage);

        // 🔹 골드 아이콘 추가 (상대적 크기 적용)
        Texture goldTexture = new Texture(Gdx.files.internal("icons/coin.png"));
        Image goldIcon = new Image(new TextureRegionDrawable(new TextureRegion(goldTexture)));

        playerGoldLabel = new Label("0", skin);
        playerGoldLabel.setFontScale(screenWidth / 380f); // 기준 해상도 대비 크기 조절

        Table topTable = new Table();
        topTable.top().left();
        topTable.setFillParent(true);

        // 🔹 골드 아이콘과 골드량을 나란히 배치 (상대적 크기 적용)
        topTable.add(goldIcon).size(screenWidth * 0.05f, screenHeight * 0.03f).left().padLeft(screenWidth * 0.05f);
        topTable.add(playerGoldLabel).padLeft(screenWidth * 0.02f).left();

        stage.addActor(topTable);
    }

    @Override
    public void show() {
        FirebaseTowerService.loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
            @Override
            public void onSuccess(List<TowerDto> towers) {
                allTowers = towers;
                FirebaseTowerService.loadUserData(new FirebaseCallback<UserDto>() {
                    @Override
                    public void onSuccess(UserDto user) {
                        userDto = user;
                        updatePlayerGold();
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

    private void updatePlayerGold() {
        Gdx.app.postRunnable(() -> playerGoldLabel.setText(" " + userDto.getGold()));
    }

    private void initializeUI() {
        table = new Table();
        table.setFillParent(true);
        stage.addActor(table);

        for (TowerOwnershipDto towerOwnership : userDto.getUserTowers().values()) { // values() 사용
            TowerDto tower = findTowerById(towerOwnership.getTowerId());
            if (tower != null) {
                addTowerToGrid(tower, towerOwnership);
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
    
    
    
    private void addTowerToGrid(TowerDto tower, TowerOwnershipDto towerOwnership) {
        Gdx.app.postRunnable(() -> {
            try {
                float screenWidth = Gdx.graphics.getWidth();
                float screenHeight = Gdx.graphics.getHeight();

                float towerSize = screenWidth * 0.2f; // 화면 너비의 20% 크기로 설정
                float tableWidth = screenWidth * 0.25f; // 타워 컨테이너 크기 (25%)
                float tableHeight = screenHeight * 0.2f; // 타워 컨테이너 높이 (20%)
                float padding = screenWidth * 0.02f; // 패딩 (2%)

                Table towerTable = new Table();
                Image towerImage = new Image(new Texture(Gdx.files.internal(tower.getTowerImagePath())));
                towerImage.setScaling(Scaling.fit);
                Label nameLabel = new Label(tower.getTowerName(), skin);
                Label levelLabel = new Label("레벨: " + towerOwnership.getTowerLevel(), skin);

                towerTable.add(towerImage).size(towerSize).row();
                towerTable.add(nameLabel).padTop(padding).row();
                towerTable.add(levelLabel).padTop(padding);
                table.add(towerTable).pad(padding).size(tableWidth, tableHeight);

                if (table.getChildren().size % 3 == 0) {
                    table.row();
                }

                towerImage.addListener(new ClickListener() {
                    @Override
                    public void clicked(InputEvent event, float x, float y) {
                        showTowerDialog(tower, towerOwnership, levelLabel);
                    }
                });

            } catch (Exception e) {
                Gdx.app.error("TowerScreen", "Failed to add tower to grid: " + tower.getTowerImagePath(), e);
            }
        });
    }

    private void showTowerDialog(TowerDto tower, TowerOwnershipDto towerOwnership, Label levelLabel) {
        float screenWidth = Gdx.graphics.getWidth();
        float screenHeight = Gdx.graphics.getHeight();

        Dialog dialog = new Dialog("", skin);
        dialog.setModal(true);
        dialog.setMovable(false);
        dialog.setResizable(false);

        // 🔹 타워 이름 라벨 추가 (폰트 크기 조절)
        Label towerNameLabel = new Label(tower.getTowerName(), skin);
        towerNameLabel.setFontScale(screenWidth / 320f);

        // 🔹 타워 이미지 추가 (상대적 크기)
        Texture towerTexture = new Texture(Gdx.files.internal(tower.getTowerImagePath()));
        Image towerImage = new Image(new TextureRegionDrawable(new TextureRegion(towerTexture)));

        // 🔹 레벨 및 공격력 표시 (폰트 크기 조절)
        Label levelTextLabel = new Label("레벨: " + towerOwnership.getTowerLevel(), skin);
        levelTextLabel.setFontScale(screenWidth / 400f);

        float physicalAttack = tower.getTowerPhysicalAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
        float magicAttack = tower.getTowerMagicAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
        Label attackLabel = new Label("물리 공격력: " + physicalAttack + "\n마법 공격력: " + magicAttack, skin);
        attackLabel.setFontScale(screenWidth / 400f);

        // 🔹 업그레이드 버튼
        TextButton upgradeButton = new TextButton("업그레이드", skin);
        upgradeButton.getLabel().setFontScale(screenWidth / 400f);
        upgradeButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                upgradeTower(tower, towerOwnership, levelTextLabel, attackLabel, levelLabel);
            }
        });

        // 🔹 닫기 버튼 (X 아이콘 크기 조절)
        Texture closeTexture = new Texture(Gdx.files.internal("icons/cancel.png"));
        ImageButton closeButton = new ImageButton(new TextureRegionDrawable(new TextureRegion(closeTexture)));
        closeButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                dialog.hide();
            }
        });

        // 🔹 레이아웃 구성
        Table contentTable = new Table();
        contentTable.add(towerNameLabel).colspan(2).center().padBottom(screenHeight * 0.02f).row();
        contentTable.add(towerImage).size(screenWidth * 0.3f, screenHeight * 0.2f).colspan(2).center().padBottom(screenHeight * 0.02f).row();
        contentTable.add(levelTextLabel).colspan(2).center().padBottom(screenHeight * 0.01f).row();
        contentTable.add(attackLabel).colspan(2).center().padBottom(screenHeight * 0.02f).row();
        contentTable.add(upgradeButton).colspan(2).center().padBottom(screenHeight * 0.02f).row();

        // 🔹 닫기 버튼을 우측 상단에 배치
        Table titleTable = new Table();
        titleTable.add().expandX();
        titleTable.add(closeButton).size(screenWidth * 0.1f, screenHeight * 0.06f).right();

        dialog.getTitleTable().clear();
        dialog.getTitleTable().add(titleTable).expandX().fill();

        dialog.getContentTable().add(contentTable).pad(screenWidth * 0.05f);
        dialog.pack();
        dialog.show(stage);
    }

    private void upgradeTower(TowerDto tower, TowerOwnershipDto towerOwnership, Label levelTextLabel, Label attackLabel, Label levelLabel) {
        int upgradeCost = 50 * tower.getTowerGrade() * (towerOwnership.getTowerLevel() + 1);
        if (userDto.getGold() < upgradeCost) {
            System.out.println("골드 부족!");
            return;
        }

        int newGoldAmount = userDto.getGold() - upgradeCost; // 새로운 골드 값
        userDto.setGold(newGoldAmount);

        FirebaseTowerService.upgradeTowerLevel(userDto.getUserId(), towerOwnership.getTowerId(), newGoldAmount, new FirebaseCallback<Void>() {
            @Override
            public void onSuccess(Void unused) {
                towerOwnership.setTowerLevel(towerOwnership.getTowerLevel() + 1);

                float newPhysicalAttack = tower.getTowerPhysicalAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
                float newMagicAttack = tower.getTowerMagicAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());

                Gdx.app.postRunnable(() -> {
                    levelTextLabel.setText("레벨: " + towerOwnership.getTowerLevel());
                    attackLabel.setText("물리 공격력: " + newPhysicalAttack + "\n마법 공격력: " + newMagicAttack);
                    levelLabel.setText("레벨: " + towerOwnership.getTowerLevel());
                    updatePlayerGold();
                });
            }

            @Override
            public void onFailure(Exception e) {
                System.err.println("업그레이드 실패: " + e.getMessage());
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
    public void dispose() {
        stage.dispose();
        skin.dispose();
    }

	@Override
	public void resize(int width, int height) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void pause() {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void resume() {
		// TODO Auto-generated method stub
		
	}

	@Override
	public void hide() {
		// TODO Auto-generated method stub
		
	}
}

package io.github.chw3021.companydefense.screens.equipmentscreens;

import java.util.List;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
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

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.screens.MainViewScreen;

public class TowerScreenView extends Table {
    private Game game;
    private Skin skin;
    private UserDto userDto;
    private List<TowerDto> allTowers;
    private FirebaseServiceImpl firebaseService;
    private TextureRegionDrawable towerTableBackground;
    private MainViewScreen mainViewScreen;

    public Table towerGrid;
    
    private float screenWidth = Gdx.graphics.getWidth();
    private float screenHeight = Gdx.graphics.getHeight();

    public TowerScreenView(Game game, MainViewScreen mainViewScreen) {
        this.game = game;
        this.mainViewScreen = mainViewScreen;

        firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        firebaseService.addLoadingListener(mainViewScreen);
        

        Gdx.app.postRunnable(() -> {
            this.towerTableBackground = new TextureRegionDrawable(new TextureRegion(new Texture(Gdx.files.internal("background/card.png"))));
            setFillParent(true);
            skin = new Skin(Gdx.files.internal("ui/companyskin.json"));
            loadData();
        });
    }


    
    /** 🔹 UI 초기화 */
    private void initializeUI() {
        towerGrid = new Table();
        towerGrid.top();


        int columnCount = 3; // 한 줄에 3개씩 배치
        int index = 0;

        for (TowerOwnershipDto towerOwnership : userDto.getUserTowers().values()) {
            TowerDto tower = findTowerById(towerOwnership.getTowerId());
            if (tower != null) {
                towerGrid.add(createTowerCell(tower, towerOwnership)).expandX()
                         .size(screenWidth * 0.26f, screenHeight * 0.3f).pad(screenWidth * 0.012f); // 💡 크기 조절

                index++;
                if (index % columnCount == 0) {
                    towerGrid.row().expand();
                }
            }
        }

        towerGrid.setWidth(this.getWidth());
        this.add(towerGrid).expandX().row(); // 💡 그리드 크기 맞추기
    }

    /** 🔹 타워 UI 요소 생성 */
    private Table createTowerCell(TowerDto tower, TowerOwnershipDto towerOwnership) {
        Table towerTable = new Table();
        towerTable.top();

        
        Image towerImage = new Image(new Texture(Gdx.files.internal(tower.getTowerImagePath())));
        towerImage.setScaling(Scaling.fit);
        Label nameLabel = new Label(tower.getTowerName(), skin);
        Label levelLabel = new Label("레벨: " + towerOwnership.getTowerLevel(), skin);
        towerImage.setSize(screenWidth * 0.2f, screenHeight * 0.16f);
        nameLabel.setSize(screenWidth * 0.02f,screenWidth * 0.02f);
        nameLabel.setFontScale(screenWidth * 0.0015f);
        nameLabel.setColor(Color.BLACK);
        levelLabel.setSize(screenWidth * 0.02f,screenWidth * 0.02f);
        levelLabel.setFontScale(screenWidth * 0.0017f);
        levelLabel.setColor(Color.BLACK);
        
        towerTable.add(towerImage).size(screenWidth * 0.2f, screenHeight * 0.16f).padTop(screenHeight*0.022f).expandX().row();
        towerTable.add(nameLabel).padTop(screenHeight * 0.035f).row();
        towerTable.add(levelLabel).padTop(screenHeight * 0.02f);

        // 타워 정보 테이블 배경 적용
        towerTableBackground.setMinWidth(towerTable.getWidth());
        towerTableBackground.setMinHeight(towerTable.getHeight());
        towerTable.setBackground(towerTableBackground);
        towerTable.setSize(screenWidth * 0.25f, screenHeight * 0.28f); 

        // 💡 타워 클릭 이벤트 추가
        towerTable.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                showTowerDialog(tower, towerOwnership, levelLabel);
            }
        });
        return towerTable;
    }
    
    /** 🔹 ID로 타워 찾기 */
    private TowerDto findTowerById(String towerId) {
        for (TowerDto tower : allTowers) {
            if (tower.getTowerId().equals(towerId)) {
                return tower;
            }
        }
        return null;
    }

    /** 🔹 Firebase에서 데이터 로드 */
    private void loadData() {
        FirebaseTowerService.loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
            @Override
            public void onSuccess(List<TowerDto> towers) {
                allTowers = towers;
                FirebaseTowerService.loadUserData(new FirebaseCallback<UserDto>() {
                    @Override
                    public void onSuccess(UserDto user) {
                        userDto = user;
                        Gdx.app.postRunnable(() -> {
                            initializeUI();
                        });
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

    
    
    /** 🔹 타워 정보 팝업 */
    private void showTowerDialog(TowerDto tower, TowerOwnershipDto towerOwnership, Label levelLabel) {
        Dialog dialog = new Dialog("", skin);
        dialog.setModal(true);

        Label towerNameLabel = new Label(tower.getTowerName(), skin);
        Image towerImage = new Image(new Texture(Gdx.files.internal(tower.getTowerImagePath())));
        Label levelTextLabel = new Label("레벨: " + towerOwnership.getTowerLevel(), skin);

        float physicalAttack = tower.getTowerPhysicalAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
        float magicAttack = tower.getTowerMagicAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
        Label attackLabel = new Label("물리 공격력: " + physicalAttack + "\n마법 공격력: " + magicAttack, skin);

        TextButton upgradeButton = new TextButton("업그레이드", skin);
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

        Table contentTable = new Table();
        contentTable.add(towerNameLabel).colspan(2).center().row();
        contentTable.add(towerImage).size(screenWidth * 0.4f, screenHeight * 0.4f).colspan(2).center().row();  // 비례적으로 크기 지정
        contentTable.add(levelTextLabel).colspan(2).center().row();
        contentTable.add(attackLabel).colspan(2).center().row();
        contentTable.add(upgradeButton).colspan(2).center().row();

        // 🔹 닫기 버튼을 우측 상단에 배치
        Table titleTable = new Table();
        titleTable.add().expandX();
        titleTable.add(closeButton).size(screenWidth * 0.1f, screenHeight * 0.06f).right();  // 비례적으로 크기 지정

        dialog.getContentTable().add(contentTable).pad(screenWidth * 0.05f);  // 비례적으로 패딩 지정
        dialog.pack();
        // 🔹 Stage에 리스너 추가하여 다이얼로그 바깥을 클릭하면 닫히도록 설정
        mainViewScreen.addDialogListener(dialog);
        dialog.show(this.getStage());
    }
    /** 🔹 타워 업그레이드 */
    private void upgradeTower(TowerDto tower, TowerOwnershipDto towerOwnership, Label levelTextLabel, Label attackLabel, Label levelLabel) {
        int upgradeCost = 50 * tower.getTowerGrade() * (towerOwnership.getTowerLevel() + 1);
        if (userDto.getGold() < upgradeCost) {
            System.out.println("골드 부족!");
            return;
        }

        int newGoldAmount = userDto.getGold() - upgradeCost;
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
                    mainViewScreen.updatePlayerGold();
                });
            }

            @Override
            public void onFailure(Exception e) {
                System.err.println("업그레이드 실패: " + e.getMessage());
            }
        });
    }
}

package io.github.chw3021.companydefense.screens.equipmentscreens;

import java.util.List;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
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

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;

public class TowerScreenView extends Table {
    private Game game;
    private Skin skin;
    private UserDto userDto;
    private List<TowerDto> allTowers;
    private FirebaseServiceImpl firebaseService;
    private Label playerGoldLabel;
    
    private float screenWidth = Gdx.graphics.getWidth();
    private float screenHeight = Gdx.graphics.getHeight();

    public TowerScreenView(Game game) {
        this.game = game;
        this.setFillParent(true);
        firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        loadData();

        Gdx.app.postRunnable(() -> {
            // 🔹 UI 초기화
            skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
            createTopBar();
        });
    }

    /** 🔹 상단 골드 표시 UI */
    private void createTopBar() {
        Table topTable = new Table();
        topTable.top().left();
        topTable.setFillParent(true);

        // 🔹 골드 아이콘
        Texture goldTexture = new Texture(Gdx.files.internal("icons/coin.png"));
        Image goldIcon = new Image(new TextureRegionDrawable(new TextureRegion(goldTexture)));

        playerGoldLabel = new Label("0", skin);

        topTable.add(goldIcon).size(screenWidth * 0.08f, screenHeight * 0.08f).padLeft(screenWidth * 0.05f);  // 비례적으로 크기 지정
        topTable.add(playerGoldLabel).padLeft(screenWidth * 0.02f);  // 비례적으로 패딩 지정


        this.addActor(topTable);
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
                            updatePlayerGold();
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

    /** 🔹 플레이어 골드 업데이트 */
    private void updatePlayerGold() {
        Gdx.app.postRunnable(() -> playerGoldLabel.setText(" " + userDto.getGold()));
    }

    /** 🔹 타워 UI 생성 */
    private void initializeUI() {
        this.clear(); // 기존 요소 제거
        createTopBar(); // 다시 추가

        for (TowerOwnershipDto towerOwnership : userDto.getUserTowers().values()) {
            TowerDto tower = findTowerById(towerOwnership.getTowerId());
            if (tower != null) {
                addTowerToGrid(tower, towerOwnership);
            }
        }
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

    /** 🔹 타워 UI 추가 */
    private void addTowerToGrid(TowerDto tower, TowerOwnershipDto towerOwnership) {
        Gdx.app.postRunnable(() -> {
            Table towerTable = new Table();
            Image towerImage = new Image(new Texture(Gdx.files.internal(tower.getTowerImagePath())));
            Label nameLabel = new Label(tower.getTowerName(), skin);
            Label levelLabel = new Label("레벨: " + towerOwnership.getTowerLevel(), skin);

            towerTable.add(towerImage).size(screenWidth * 0.2f, screenHeight * 0.2f).row();  // 비례적으로 크기 지정
            towerTable.add(nameLabel).padTop(screenHeight * 0.02f).row();  // 비례적으로 패딩 지정
            towerTable.add(levelLabel).padTop(screenHeight * 0.01f);  // 비례적으로 패딩 지정
            this.add(towerTable).pad(screenWidth * 0.03f).size(screenWidth * 0.3f, screenHeight * 0.4f);  // 비례적으로 크기 지정

            if (this.getChildren().size % 3 == 0) {
                this.row();
            }

            towerImage.addListener(new ClickListener() {
                @Override
                public void clicked(InputEvent event, float x, float y) {
                    showTowerDialog(tower, towerOwnership, levelLabel);
                }
            });
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
                    updatePlayerGold();
                });
            }

            @Override
            public void onFailure(Exception e) {
                System.err.println("업그레이드 실패: " + e.getMessage());
            }
        });
    }
}

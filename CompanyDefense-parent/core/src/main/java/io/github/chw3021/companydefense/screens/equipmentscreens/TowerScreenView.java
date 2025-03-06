package io.github.chw3021.companydefense.screens.equipmentscreens;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.stream.Collectors;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Pixmap;
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
import io.github.chw3021.companydefense.dto.SkillDto;
import io.github.chw3021.companydefense.dto.TowerDto;
import io.github.chw3021.companydefense.dto.TowerOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.screens.MainViewScreen;

public class TowerScreenView extends Table {
    private Skin skin;
    private UserDto userDto;
    private List<TowerDto> allTowers;
    private Map<String, SkillDto> skillsMap;
    private FirebaseServiceImpl firebaseService;
    private TextureRegionDrawable towerTableBackground;
    private MainViewScreen mainViewScreen;

    public Table towerGrid;
    
    private float screenWidth = Gdx.graphics.getWidth();
    private float screenHeight = Gdx.graphics.getHeight();

    public TowerScreenView(Game game, MainViewScreen mainViewScreen) {
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

	 private void loadData() {
		 CompletableFuture<List<SkillDto>> skillFuture = new CompletableFuture<>();
		 CompletableFuture<UserDto> userFuture = new CompletableFuture<>();
		 CompletableFuture<List<TowerDto>> towerFuture = new CompletableFuture<>();

		 // 1. 병렬로 Firebase 데이터 요청
		 FirebaseTowerService.loadAllSkills(new FirebaseCallback<List<SkillDto>>() {
			 @Override
			 public void onSuccess(List<SkillDto> allSkills) {
				 skillFuture.complete(allSkills);
			 }

			 @Override
			 public void onFailure(Exception e) {
				 skillFuture.completeExceptionally(e);
			 }
		 });

		 FirebaseTowerService.loadUserData(new FirebaseCallback<UserDto>() {
			 @Override
			 public void onSuccess(UserDto user) {
				 userFuture.complete(user);
			 }

			 @Override
			 public void onFailure(Exception e) {
				 userFuture.completeExceptionally(e);
			 }
		 });

		 FirebaseTowerService.loadAllTowers(new FirebaseCallback<List<TowerDto>>() {
			 @Override
			 public void onSuccess(List<TowerDto> allTowers) {
	            towerFuture.complete(allTowers);
			 }

			 @Override
			 public void onFailure(Exception e) {
	            towerFuture.completeExceptionally(e);
			 }
		 });

		 // 2. 모든 데이터 요청이 완료된 후 실행
		 CompletableFuture.allOf(skillFuture, userFuture, towerFuture).thenAccept(v -> {
			 try {
				 List<SkillDto> allSkills = skillFuture.get();
				 userDto = userFuture.get();
				 allTowers = towerFuture.get();


				 // 3. 데이터를 Map으로 변환 (빠른 조회 가능)
				 skillsMap = allSkills.stream()
					 .collect(Collectors.toMap(SkillDto::getSkillId, skill -> skill));

				 // 4. LibGDX 스레드에서 실행 (UI 갱신)
				 Gdx.app.postRunnable(() -> {
					 initializeUI();
				 });

			 } catch (InterruptedException | ExecutionException e) {
				 Gdx.app.error("StageParent", "데이터 로딩 중 오류 발생", e);
			 }
		 });
	 }


	 private void showTowerDialog(TowerDto tower, TowerOwnershipDto towerOwnership, Label levelLabel) {
		    Dialog dialog = new Dialog(tower.getTowerName(), skin);
		    dialog.setModal(true);
	
		    Image towerImage = new Image(new Texture(Gdx.files.internal(tower.getTowerImagePath())));
		    Label levelTextLabel = new Label("레벨: " + towerOwnership.getTowerLevel(), skin);
		    Label upgradeCostLabel = new Label(String.format("%d", 50 * tower.getTowerGrade() * (towerOwnership.getTowerLevel() + 1)), skin);
		    Table upgradeCostTable = new Table();
		    upgradeCostTable.add(new Image(new Texture(Gdx.files.internal("icons/coin.png")))).width(dialog.getWidth()*0.05f).height(dialog.getWidth()*0.05f); // 버튼 크기 지정
		    upgradeCostTable.add(upgradeCostLabel).pad(5);
		    
		    // 부동소수점 처리
		    float physicalAttack = tower.getTowerPhysicalAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
		    float magicAttack = tower.getTowerMagicAttack() * (1 + tower.getTowerAttackMult() * towerOwnership.getTowerLevel());
		    String physicalAttackText = String.format("물리 공격력: %.1f", physicalAttack);
		    String magicAttackText = String.format("마법 공격력: %.1f", magicAttack);
		    Label attackLabel = new Label(physicalAttackText + "\n" + magicAttackText, skin);
	
		    TextButton upgradeButton = new TextButton("업그레이드", skin);
		    upgradeButton.addListener(new ClickListener() {
		        @Override
		        public void clicked(InputEvent event, float x, float y) {
		            upgradeTower(tower, towerOwnership, levelTextLabel, attackLabel, levelLabel, upgradeCostLabel);
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
		    // 스킬 아이콘 가져오기
		    String skillId = tower.getTowerId().replace("tower_", "");
		    SkillDto skill = skillsMap.get(skillId);
		    
		 // ImageButton 스타일 설정
		    ImageButton.ImageButtonStyle skillButtonStyle = new ImageButton.ImageButtonStyle();
		    TextureRegionDrawable skillIconDrawable = new TextureRegionDrawable(new TextureRegion(new Texture(Gdx.files.internal(skill.getSkillImagePath()))));
		    skillButtonStyle.imageUp = skillIconDrawable;
		    skillButtonStyle.imageDown = skillIconDrawable;

		    // 버튼 크기
		    float buttonWidth = screenWidth * 0.08f;
		    float buttonHeight = screenHeight * 0.08f;

		    // 희미하고 밝은 둥근 사각형 배경 생성 (버튼 크기보다 살짝 크게 설정)
		    Pixmap pixmap = new Pixmap((int) buttonWidth, (int) buttonHeight, Pixmap.Format.RGBA8888);
		    pixmap.setColor(new Color(1, 1, 1, 0.5f)); // 흰색, 투명도 70%

		    // 둥근 모서리 적용 (원형 마스킹)
		    int cornerRadius = 15; // 모서리 반경 (값이 클수록 둥글어짐)

		    // 배경 사각형
		    pixmap.fillRectangle(cornerRadius, 0, (int) buttonWidth - 2 * cornerRadius, (int) buttonHeight);
		    pixmap.fillRectangle(0, cornerRadius, (int) buttonWidth, (int) buttonHeight - 2 * cornerRadius);

		    // 모서리 둥글게 (4개의 원)
		    pixmap.fillCircle(cornerRadius, cornerRadius, cornerRadius); // 왼쪽 상단
		    pixmap.fillCircle((int) buttonWidth - cornerRadius, cornerRadius, cornerRadius); // 오른쪽 상단
		    pixmap.fillCircle(cornerRadius, (int) buttonHeight - cornerRadius, cornerRadius); // 왼쪽 하단
		    pixmap.fillCircle((int) buttonWidth - cornerRadius, (int) buttonHeight - cornerRadius, cornerRadius); // 오른쪽 하단

		    // Texture 생성
		    Texture roundedTexture = new Texture(pixmap);
		    TextureRegionDrawable roundedBackground = new TextureRegionDrawable(new TextureRegion(roundedTexture));

		    // 배경이 이미지보다 살짝 크도록 설정
		    skillButtonStyle.up = roundedBackground;
		    skillButtonStyle.down = roundedBackground.tint(new Color(0.9f, 0.9f, 0.9f, 0.7f)); // 클릭 시 밝아짐

		    // ImageButton 생성
		    ImageButton skillButton = new ImageButton(skillButtonStyle);
		    skillButton.setSize(buttonWidth, buttonHeight);
		    skillButton.pad(5); // 이미지와 배경 사이에 패딩 추가

		    // Pixmap 메모리 해제 (메모리 누수 방지)
		    pixmap.dispose();


		    // 기존 이벤트 리스너 적용
		    skillButton.addListener(new ClickListener() {
		        @Override
		        public void clicked(InputEvent event, float x, float y) {
		            Dialog skillDialog = new Dialog(skill.getSkillName(), skin);
		            Label skillDescriptionLabel = new Label(skill.getSkillDescription(), skin);
		            skillDescriptionLabel.setWrap(true);

		            Table contentTable = new Table();
		            contentTable.add(skillDescriptionLabel).width(screenWidth * 0.3f).pad(10).row();

		            skillDialog.getContentTable().add(contentTable);
		            skillDialog.button("닫기", true);
		            skillDialog.pack();

		            float dialogX = event.getStageX();
		            float dialogY = event.getStageY();
		            skillDialog.show(getStage());
		            skillDialog.setPosition(dialogX, dialogY - skillDialog.getHeight());

		            if (dialogX + skillDialog.getWidth() > screenWidth) {
		                skillDialog.setX(screenWidth - skillDialog.getWidth());
		            }
		            if (dialogY - skillDialog.getHeight() < 0) {
		                skillDialog.setY(0);
		            }
		        }
		    });
		    
		    towerImage.setSize(screenWidth * 0.3f, screenHeight * 0.3f);

		    contentTable.add(towerImage).size(screenWidth * 0.3f, screenHeight * 0.3f).colspan(2).center().row();
		    contentTable.add(skillButton).size(screenWidth * 0.08f, screenWidth * 0.08f).colspan(2).center().row();
		    contentTable.add(levelTextLabel).colspan(2).center().row();
		    contentTable.add(attackLabel).colspan(2).center().row();
		    contentTable.add(upgradeCostTable).colspan(2).center().row();
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
    private void upgradeTower(TowerDto tower, TowerOwnershipDto towerOwnership, Label levelTextLabel, Label attackLabel, Label levelLabel, Label upgradeCostLabel) {
        int upgradeCost = 50 * tower.getTowerGrade() * (towerOwnership.getTowerLevel() + 1);
        if (userDto.getGold() < upgradeCost) {
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
                    // 소수점 2자리로 포맷팅하여 표시
                    String physicalAttackStr = String.format("%.1f", newPhysicalAttack);
                    String magicAttackStr = String.format("%.1f", newMagicAttack);
                    int upgradeCost = 50 * tower.getTowerGrade() * (towerOwnership.getTowerLevel() + 1);
                    // 레이블에 적용
                    upgradeCostLabel.setText(upgradeCost);
                    attackLabel.setText("물리 공격력: " + physicalAttackStr + "\n마법 공격력: " + magicAttackStr);
                    levelLabel.setText("레벨: " + towerOwnership.getTowerLevel());
                    mainViewScreen.updatePlayerGold(newGoldAmount);
                });
            }

            @Override
            public void onFailure(Exception e) {
                System.err.println("업그레이드 실패: " + e.getMessage());
            }
        });
    }
}

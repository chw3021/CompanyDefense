package io.github.chw3021.companydefense.screens.equipmentscreens;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.stream.Collectors;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.scenes.scene2d.Actor;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.actions.Actions;
import com.badlogic.gdx.scenes.scene2d.ui.Dialog;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.scenes.scene2d.utils.TextureRegionDrawable;
import com.badlogic.gdx.utils.Scaling;
import com.badlogic.gdx.utils.SnapshotArray;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.dto.HobbyDto;
import io.github.chw3021.companydefense.dto.HobbyOwnershipDto;
import io.github.chw3021.companydefense.dto.UserDto;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseServiceImpl;
import io.github.chw3021.companydefense.firebase.FirebaseTowerService;
import io.github.chw3021.companydefense.screens.MainViewScreen;

public class HobbyScreenView extends Table {
    private Game game;
    private Skin skin;
    private UserDto userDto;
    private Map<String, HobbyDto> hobbyMap;
    private FirebaseServiceImpl firebaseService;
    private TextureRegionDrawable hobbyTableBackground;
    private MainViewScreen mainViewScreen;

    public Table hobbyGrid;
    
    private float screenWidth = Gdx.graphics.getWidth();
    private float screenHeight = Gdx.graphics.getHeight();

    public HobbyScreenView(Game game, MainViewScreen mainViewScreen) {
        this.game = game;
        this.mainViewScreen = mainViewScreen;

        firebaseService = (FirebaseServiceImpl) Main.getInstance().getFirebaseService();
        firebaseService.addLoadingListener(mainViewScreen);
        
        Gdx.app.postRunnable(() -> {
            this.hobbyTableBackground = new TextureRegionDrawable(new TextureRegion(new Texture(Gdx.files.internal("background/hobbycard.png"))));
            setFillParent(true);
            skin = new Skin(Gdx.files.internal("ui/companyskin.json"));
            loadData();
        });
    }

    /** 🔹 UI 초기화 */
    private void initializeUI() {
        hobbyGrid = new Table();
        hobbyGrid.top();

        int columnCount = 3; // 한 줄에 3개씩 배치
        int index = 0;

        for (HobbyOwnershipDto hobbyOwnership : userDto.getUserHobbies().values()) {
            hobbyGrid.add(createHobbyCell(hobbyOwnership)).expandX()
                     .size(screenWidth * 0.26f, screenHeight * 0.3f).pad(screenWidth * 0.012f); // 💡 크기 조절

            index++;
            if (index % columnCount == 0) {
                hobbyGrid.row().expand();
            }
        }

        hobbyGrid.setWidth(this.getWidth());
        this.add(hobbyGrid).expandX().row(); // 💡 그리드 크기 맞추기

        // 하단 중앙에 취미 활동 버튼 추가
        TextButton activityButton = new TextButton("취미 활동 하기!", skin);
        activityButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                performHobbyActivity();
            }
        });
        this.add(activityButton).center().padTop(screenHeight * 0.02f);
    }

    /** 🔹 취미 UI 요소 생성 */
    private Table createHobbyCell(HobbyOwnershipDto hobbyOwnership) {
        Table hobbyTable = new Table();
        hobbyTable.top();

        String hobbyId = hobbyOwnership.getHobbyId();
        String hobbyName = getHobbyName(hobbyId);
        String hobbyIconPath = getHobbyIconPath(hobbyId);

        Image hobbyImage = new Image(new Texture(Gdx.files.internal(hobbyIconPath)));
        hobbyImage.setScaling(Scaling.fit);
        Label nameLabel = new Label(hobbyName, skin);
        Label levelLabel = new Label("레벨: " + hobbyOwnership.getHobbyLevel(), skin);
        hobbyImage.setSize(screenWidth * 0.2f, screenHeight * 0.16f);
        nameLabel.setSize(screenWidth * 0.02f,screenWidth * 0.02f);
        nameLabel.setFontScale(screenWidth * 0.0015f);
        nameLabel.setColor(Color.BLACK);
        levelLabel.setSize(screenWidth * 0.02f,screenWidth * 0.02f);
        levelLabel.setFontScale(screenWidth * 0.0017f);
        levelLabel.setColor(Color.BLACK);
        
        hobbyTable.add(hobbyImage).size(screenWidth * 0.2f, screenHeight * 0.16f).padTop(screenHeight*0.022f).expandX().row();
        hobbyTable.add(nameLabel).padTop(screenHeight * 0.035f).row();
        hobbyTable.add(levelLabel).padTop(screenHeight * 0.02f);

        // 타워 정보 테이블 배경 적용
        hobbyTableBackground.setMinWidth(hobbyTable.getWidth());
        hobbyTableBackground.setMinHeight(hobbyTable.getHeight());
        hobbyTable.setBackground(hobbyTableBackground);
        hobbyTable.setSize(screenWidth * 0.25f, screenHeight * 0.28f); 
        // 💡 취미 클릭 이벤트 추가
        hobbyTable.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                showHobbyDialog(hobbyId, hobbyName, hobbyOwnership, levelLabel);
            }
        });
        return hobbyTable;
    }


    
    private String getHobbyName(String hobbyId) {
        return hobbyMap.get(hobbyId).getHobbyName();
    }
    
    
    private String getHobbyIconPath(String hobbyId) {
        return hobbyMap.get(hobbyId).getHobbyImagePath();
    }
    
    /** 🔹 취미 효과 텍스트 가져오기 */
    private String getHobbyEffectText(String hobbyId, int level) {
        HobbyDto hobby = hobbyMap.get(hobbyId);
        if (hobby == null) return "알 수 없음";

        String description = hobby.getHobbyDescription();
        double effectValue = level * 0.001 * 100;
        return description + String.format(" (%.2f%%)", effectValue);
    }
    
        
    private void performHobbyActivity() {
        if (userDto.getTime() < 1) {
            return;
        }

        int newTimeAmount = userDto.getTime() - 1;
        userDto.setTime(newTimeAmount);

        List<HobbyOwnershipDto> hobbies = new ArrayList<>(userDto.getUserHobbies().values());
        if (hobbies.isEmpty()) {
            return;
        }

        HobbyOwnershipDto randomHobby = hobbies.get(new Random().nextInt(hobbies.size()));
        randomHobby.setHobbyLevel(randomHobby.getHobbyLevel() + 1);

        FirebaseTowerService.updateUserHobbies(userDto.getUserId(), randomHobby.getHobbyId(), newTimeAmount, userDto.getUserHobbies(), new FirebaseCallback<Void>() {
            @Override
            public void onSuccess(Void unused) {
                Gdx.app.postRunnable(() -> {
                    Label levelLabel = findLevelLabel(randomHobby.getHobbyId());
                    if (levelLabel != null) {
                        levelLabel.setText("레벨: " + randomHobby.getHobbyLevel());

                        // 🔹 반짝임 효과 추가
                        Table hobbyCell = findHobbyCell(randomHobby.getHobbyId());
                        if (hobbyCell != null) {
                            hobbyCell.addAction(Actions.sequence(
                                Actions.alpha(0.5f, 0.1f), // 반투명하게
                                Actions.alpha(1.0f, 0.1f)  // 다시 불투명하게
                            ));
                        }
                    }
                    mainViewScreen.updatePlayerTime(newTimeAmount);
                });
            }

            @Override
            public void onFailure(Exception e) {
                System.err.println("취미 활동 실패: " + e.getMessage());
            }
        });
    }

    // 🔹 HobbyCell을 찾는 메서드 추가
    private Table findHobbyCell(String hobbyId) {
        for (Actor actor : hobbyGrid.getChildren()) {
            if (actor instanceof Table) {
                Table hobbyTable = (Table) actor;
                // HobbyCell 내의 nameLabel을 찾아서 hobbyId와 비교
                for (Actor child : hobbyTable.getChildren()) {
                    if (child instanceof Label) {
                        Label nameLabel = (Label) child;
                        if (nameLabel.getText().toString().equals(getHobbyName(hobbyId))) {
                            return hobbyTable;
                        }
                    }
                }
            }
        }
        return null;
    }

    
	private Label findLevelLabel(String hobbyId) {
	    for (Actor actor : hobbyGrid.getChildren()) {
	        if (actor instanceof Table) {
	            Table hobbyTable = (Table) actor;
	            SnapshotArray<Actor> children = hobbyTable.getChildren();
	            Actor[] array = children.begin();
	            for (int i = 0, n = children.size; i < n; i++) {
	                Actor child = array[i];
	                if (child instanceof Label) {
	                    Label label = (Label) child;
	                    if (label.getText().toString().contains("레벨:")) {
	                        Table parentTable = (Table) label.getParent();
	                        if (parentTable != null) {
	                            SnapshotArray<Actor> parentChildren = parentTable.getChildren();
	                            Actor[] parentArray = parentChildren.begin();
	                            for (int j = 0, m = parentChildren.size; j < m; j++) {
	                                Actor sibling = parentArray[j];
	                                if (sibling instanceof Label) {
	                                    Label siblingLabel = (Label) sibling;
	                                    if (siblingLabel.getText().toString().equals(getHobbyName(hobbyId))) {
	                                        parentChildren.end();
	                                        children.end();
	                                        return label;
	                                    }
	                                }
	                            }
	                            parentChildren.end();
	                        }
	                    }
	                }
	            }
	            children.end();
	        }
	    }
	    return null;
	}
	
    /** 🔹 취미 상세 내용 표시 */
    private void showHobbyDialog(String hobbyId, String hobbyName, HobbyOwnershipDto hobbyOwnership, Label levelLabel) {
        Dialog dialog = new Dialog("", skin);
        dialog.setModal(true);

        Label hobbyNameLabel = new Label(hobbyName, skin);
        Image hobbyImage = new Image(new Texture(Gdx.files.internal(getHobbyIconPath(hobbyId))));
        Label levelTextLabel = new Label("레벨: " + hobbyOwnership.getHobbyLevel(), skin);

        String effectText = getHobbyEffectText(hobbyId, hobbyOwnership.getHobbyLevel());
        Label effectLabel = new Label(effectText, skin);

        TextButton closeButton = new TextButton("닫기", skin);
        closeButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                dialog.hide();
            }
        });

        Table contentTable = new Table();
        contentTable.add(hobbyImage).size(screenWidth * 0.3f, screenHeight * 0.3f).colspan(2).center().row();
        contentTable.add(hobbyNameLabel).colspan(2).center().row();
        contentTable.add(levelTextLabel).colspan(2).center().row();
        contentTable.add(effectLabel).colspan(2).center().row();
        contentTable.add(closeButton).colspan(2).center().row();

        dialog.getContentTable().add(contentTable).pad(screenWidth * 0.05f);
        dialog.pack();
        dialog.show(this.getStage());
    }

    private void loadData() {
        CompletableFuture<UserDto> userFuture = new CompletableFuture<>();
		 CompletableFuture<List<HobbyDto>> hobbyFuture = new CompletableFuture<>();

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

		 FirebaseTowerService.loadAllHobbies(new FirebaseCallback<List<HobbyDto>>() {
			 @Override
			 public void onSuccess(List<HobbyDto> allSkills) {
				 hobbyFuture.complete(allSkills);
			 }

			 @Override
			 public void onFailure(Exception e) {
				 hobbyFuture.completeExceptionally(e);
			 }
		 });

		 // 2. 모든 데이터 요청이 완료된 후 실행
		 CompletableFuture.allOf(hobbyFuture, userFuture).thenAccept(v -> {
			 try {
			 	List<HobbyDto> allHobbies = hobbyFuture.get();

			 	hobbyMap = allHobbies.stream()
			 			.collect(Collectors.toMap(HobbyDto::getHobbyId, hobby -> hobby));
			 	
	            userDto = userFuture.get();
	            Gdx.app.postRunnable(() -> {
	                initializeUI();
	            });

			 } catch (InterruptedException | ExecutionException e) {
				 Gdx.app.error("StageParent", "데이터 로딩 중 오류 발생", e);
			 }
		 });
    }
}
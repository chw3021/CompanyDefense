package io.github.chw3021.companydefense.screens.menu;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Label.LabelStyle;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.ui.TextField;
import com.badlogic.gdx.scenes.scene2d.ui.Window;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Align;
import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseService;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

public class MenuScreenPopup extends Window {
    private final FirebaseService firebaseService;
    private final Stage stage;
    private final Skin skin;
    private Label nicknameLabel; // 닉네임 표시를 위한 레이블

    public MenuScreenPopup(Skin skin, FirebaseService firebaseService, Stage stage) {
        super("메뉴", skin);
        this.firebaseService = firebaseService;
        this.stage = stage;
        this.skin = skin;
        
        this.setSize(Gdx.graphics.getWidth()*0.5f, Gdx.graphics.getHeight()*0.6f);
        this.setPosition(Gdx.graphics.getWidth()*0.25f, Gdx.graphics.getHeight()*0.3f);

        // 닉네임 표시 라벨 추가
        LabelStyle nicknameStyle = new LabelStyle(skin.get(LabelStyle.class));
        nicknameStyle.fontColor = Color.GOLD; // 닉네임을 금색으로 표시
        nicknameLabel = new Label("사용자: 로딩 중...", nicknameStyle);
        nicknameLabel.setAlignment(Align.center);
        
        this.add(nicknameLabel).pad(20).width(250).row();
        
        // 수평선 추가
        Table divider = new Table();
        divider.setBackground(skin.newDrawable("white", new Color(0.7f, 0.7f, 0.7f, 1)));
        this.add(divider).height(1).fillX().padBottom(20).row();
        
        // 기존 버튼들
        this.add(createButton("랭킹", skin, this::showRankingPopup)).width(200).pad(10);
        this.row();
        this.add(createButton("닉네임 변경", skin, this::showChangeNicknamePopup)).width(200).pad(10);
        this.row();
        this.add(createButton("회원탈퇴", skin, this::showDeleteAccountConfirmation)).width(200).pad(10);

        this.setModal(true);
        
        // 사용자 닉네임 로드
        loadUserNickname();
    }
    
    // 사용자 닉네임 로드 메소드
    private void loadUserNickname() {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String userId = prefs.getString("userId", null);
        
        if (userId != null && !userId.isEmpty()) {
            firebaseService.fetchData("users/" + userId, Map.class, new FirebaseCallback<Map<String, Object>>() {
                @Override
                public void onSuccess(Map<String, Object> userData) {
                    Gdx.app.postRunnable(() -> {
                        String username = "미정";
                        if (userData != null && userData.containsKey("username")) {
                            Object usernameObj = userData.get("username");
                            if (usernameObj != null && !usernameObj.toString().trim().isEmpty()) {
                                username = usernameObj.toString();
                            }
                        }
                        updateNicknameDisplay(username);
                    });
                }
                
                @Override
                public void onFailure(Exception e) {
                    Gdx.app.error("Firebase", "사용자 데이터를 불러오는데 실패했습니다: " + e.getMessage());
                    Gdx.app.postRunnable(() -> updateNicknameDisplay("미정"));
                }
            });
        } else {
            updateNicknameDisplay("미정");
        }
    }
    
    // 닉네임 표시 업데이트 메소드
    private void updateNicknameDisplay(String nickname) {
        nicknameLabel.setText("사용자: " + nickname);
    }

    private TextButton createButton(String text, Skin skin, Runnable action) {
        TextButton button = new TextButton(text, skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                action.run();
            }
        });
        return button;
    }

    // 랭킹 팝업 표시
    private void showRankingPopup() {
        firebaseService.fetchData("users", Map.class, new FirebaseCallback<Map<String, Object>>() {
            @Override
            public void onSuccess(Map<String, Object> users) {
                Gdx.app.postRunnable(() -> {
                    // 사용자 정보 및 점수 추출 (Map<String, Integer> 형태로 사용자ID와 점수 저장)
                    List<UserScore> userScores = new ArrayList<>();
                    
                    for (Map.Entry<String, Object> entry : users.entrySet()) {
                        String userId = entry.getKey();
                        if (entry.getValue() instanceof Map) {
                            @SuppressWarnings("unchecked")
                            Map<String, Object> userData = (Map<String, Object>) entry.getValue();
                            if (userData.containsKey("userHighScore")) {
                                Integer score;
                                Object scoreObj = userData.get("userHighScore");
                                if (scoreObj instanceof Integer) {
                                    score = (Integer) scoreObj;
                                } else if (scoreObj instanceof Double) {
                                    score = ((Double) scoreObj).intValue();
                                } else if (scoreObj instanceof String) {
                                    try {
                                        score = Integer.parseInt((String) scoreObj);
                                    } catch (NumberFormatException e) {
                                        continue;
                                    }
                                } else {
                                    continue;
                                }
                                
                                String username = "Unknown";
                                if (userData.containsKey("username")) {
                                    username = userData.get("username").toString();
                                }
                                
                                userScores.add(new UserScore(userId, username, score));
                            }
                        }
                    }
                    
                    // 점수를 기준으로 내림차순 정렬
                    Collections.sort(userScores, (a, b) -> b.score.compareTo(a.score));
                    
                    // 상위 5명만 선택 (또는 전체 인원수가 5명 미만이면 모두)
                    int topCount = Math.min(userScores.size(), 5);
                    List<UserScore> topScores = userScores.subList(0, topCount);
                    
                    createRankingWindow(topScores);
                });
            }

            @Override
            public void onFailure(Exception e) {
                Gdx.app.error("Firebase", "랭킹 데이터를 가져오는데 실패했습니다: " + e.getMessage());
                Gdx.app.postRunnable(() -> {
                    Window errorWindow = new Window("오류", skin);
                    errorWindow.add(new Label("랭킹 데이터를 불러올 수 없습니다.", skin)).pad(20);
                    errorWindow.row();
                    TextButton closeButton = new TextButton("닫기", skin);
                    closeButton.addListener(new ClickListener() {
                        @Override
                        public void clicked(InputEvent event, float x, float y) {
                            errorWindow.remove();
                        }
                    });
                    errorWindow.add(closeButton).pad(10);
                    errorWindow.pack();
                    errorWindow.setPosition(stage.getWidth() / 2 - errorWindow.getWidth() / 2, 
                                           stage.getHeight() / 2 - errorWindow.getHeight() / 2);
                    errorWindow.setModal(true);
                    stage.addActor(errorWindow);
                });
            }
        });
    }
    
    // 랭킹 창 생성
    private void createRankingWindow(List<UserScore> userScores) {
        Window rankingWindow = new Window("TOP 5 랭킹", skin);
        rankingWindow.setModal(true);
        rankingWindow.setMovable(false);
        rankingWindow.setResizable(false);
        
        Table table = new Table();
        table.defaults().pad(5);
        
        // 헤더 추가
        LabelStyle headerStyle = new LabelStyle(skin.get(LabelStyle.class));
        headerStyle.fontColor = Color.YELLOW;
        
        table.add(new Label("순위", headerStyle)).width(50).align(Align.center);
        table.add(new Label("사용자", headerStyle)).width(150).align(Align.left);
        table.add(new Label("점수", headerStyle)).width(100).align(Align.right);
        table.row();
        
        // 사용자 점수 목록 추가
        for (int i = 0; i < userScores.size(); i++) {
            UserScore score = userScores.get(i);
            
            table.add(new Label((i + 1) + "", skin)).align(Align.center);
            table.add(new Label(score.username, skin)).align(Align.left);
            table.add(new Label(score.score.toString(), skin)).align(Align.right);
            table.row();
        }
        
        rankingWindow.add(table).pad(10);
        rankingWindow.row();
        
        // 닫기 버튼
        TextButton closeButton = new TextButton("닫기", skin);
        closeButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                rankingWindow.remove();
            }
        });
        rankingWindow.add(closeButton).padTop(10).padBottom(10);
        
        rankingWindow.pack();
        rankingWindow.setPosition(stage.getWidth() / 2 - rankingWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - rankingWindow.getHeight() / 2);
        stage.addActor(rankingWindow);
    }
    

    // 닉네임 변경 팝업 표시
    private void showChangeNicknamePopup() {
        Window nicknameWindow = new Window("닉네임 변경", skin);
        nicknameWindow.setModal(true);
        nicknameWindow.setMovable(false);
        nicknameWindow.setResizable(false);
        
        Table contentTable = new Table();
        contentTable.defaults().pad(10);
        
        // 닉네임 입력 필드
        Label nicknameLabel = new Label("닉네임:", skin);
        final TextField nicknameField = new TextField("", skin);
        nicknameField.setMaxLength(15); // 닉네임 최대 길이 설정
        
        // 결과 메시지 표시 라벨
        final Label resultLabel = new Label("", skin);
        resultLabel.setColor(Color.WHITE);
        
        contentTable.add(nicknameLabel).left();
        contentTable.add(nicknameField).width(200).padRight(10);
        
        // 중복체크 버튼
        TextButton checkButton = new TextButton("중복체크", skin);
        checkButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                String nickname = nicknameField.getText().trim();
                if (nickname.isEmpty()) {
                    resultLabel.setText("닉네임을 입력해주세요.");
                    resultLabel.setColor(Color.RED);
                    return;
                }
                
                checkNicknameDuplication(nickname, resultLabel, nicknameWindow);
            }
        });
        contentTable.add(checkButton);
        contentTable.row();
        
        contentTable.add(resultLabel).colspan(3).center();
        
        nicknameWindow.add(contentTable).pad(20);
        nicknameWindow.row();
        
        // 취소 버튼
        TextButton cancelButton = new TextButton("취소", skin);
        cancelButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                nicknameWindow.remove();
            }
        });
        nicknameWindow.add(cancelButton).padTop(10).padBottom(10);
        
        nicknameWindow.pack();
        nicknameWindow.setPosition(stage.getWidth() / 2 - nicknameWindow.getWidth() / 2, 
                                  stage.getHeight() / 2 - nicknameWindow.getHeight() / 2);
        stage.addActor(nicknameWindow);
    }
    
    // 닉네임 중복 체크
    private void checkNicknameDuplication(String nickname, Label resultLabel, Window parentWindow) {
        // users 경로에서 모든 사용자 데이터 가져오기
        firebaseService.fetchData("users", Map.class, new FirebaseCallback<Map<String, Object>>() {
            @Override
            public void onSuccess(Map<String, Object> usersData) {
                AtomicBoolean isDuplicate = new AtomicBoolean(false);
                
                // 모든 사용자를 순회하며 닉네임 중복 체크
                for (Object value : usersData.values()) {
                    if (value instanceof Map) {
                        @SuppressWarnings("unchecked")
                        Map<String, Object> userData = (Map<String, Object>) value;
                        if (userData.containsKey("username") && nickname.equals(userData.get("username").toString())) {
                            isDuplicate.set(true);
                            break;
                        }
                    }
                }
                
                // 결과 처리
                Gdx.app.postRunnable(() -> {
                    if (isDuplicate.get()) {
                        resultLabel.setText("이미 사용 중인 닉네임입니다.");
                        resultLabel.setColor(Color.RED);
                    } else {
                        showNicknameConfirmation(nickname, parentWindow);
                    }
                });
            }
            
            @Override
            public void onFailure(Exception e) {
                Gdx.app.error("Firebase", "닉네임 중복 확인 실패: " + e.getMessage());
                Gdx.app.postRunnable(() -> {
                    resultLabel.setText("중복 확인 중 오류가 발생했습니다.");
                    resultLabel.setColor(Color.RED);
                });
            }
        });
    }
    
    // 닉네임 변경 확인 팝업
    private void showNicknameConfirmation(String nickname, Window parentWindow) {
        Window confirmWindow = new Window("닉네임 변경 확인", skin);
        confirmWindow.setModal(true);
        confirmWindow.setMovable(false);
        confirmWindow.setResizable(false);
        
        Label messageLabel = new Label("'" + nickname + "' 는(은) 사용 가능한 닉네임입니다.\n변경하시겠습니까?", skin);
        messageLabel.setAlignment(Align.center);
        confirmWindow.add(messageLabel).pad(20);
        confirmWindow.row();
        
        Table buttonTable = new Table();
        
        // 확인 버튼
        TextButton confirmButton = new TextButton("확인", skin);
        confirmButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                updateNickname(nickname);
                confirmWindow.remove();
                parentWindow.remove(); // 닉네임 변경 창도 닫기
            }
        });
        
        // 취소 버튼
        TextButton cancelButton = new TextButton("취소", skin);
        cancelButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                confirmWindow.remove();
            }
        });
        
        buttonTable.add(confirmButton).pad(10);
        buttonTable.add(cancelButton).pad(10);
        
        confirmWindow.add(buttonTable);
        confirmWindow.pack();
        confirmWindow.setPosition(stage.getWidth() / 2 - confirmWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - confirmWindow.getHeight() / 2);
        stage.addActor(confirmWindow);
    }
    
    // 닉네임 업데이트
    private void updateNickname(String nickname) {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String userId = prefs.getString("userId", null);
        
        if (userId != null) {
            // Firebase에 닉네임 업데이트
            Map<String, Object> updates = new HashMap<>();
            updates.put("users/" + userId + "/username", nickname);
            
            firebaseService.updateData(updates, new FirebaseCallback<Void>() {
                @Override
                public void onSuccess(Void result) {
                    //Gdx.app.log("Firebase", "닉네임이 성공적으로 변경되었습니다.");
                    Gdx.app.postRunnable(() -> {
                        updateNicknameDisplay(nickname); // 닉네임 표시 업데이트
                        showNicknameUpdateSuccess(nickname);
                    });
                }
                
                @Override
                public void onFailure(Exception e) {
                    //Gdx.app.error("Firebase", "닉네임 변경 실패: " + e.getMessage());
                    Gdx.app.postRunnable(() -> showNicknameUpdateFailure());
                }
            });
        } else {
            showNicknameUpdateFailure();
        }
    }
    
    // 닉네임 변경 성공 메시지
    private void showNicknameUpdateSuccess(String nickname) {
        Window messageWindow = new Window("닉네임 변경 완료", skin);
        messageWindow.add(new Label("닉네임이 '" + nickname + "'(으)로 변경되었습니다.", skin)).pad(20);
        messageWindow.row();
        
        TextButton okButton = new TextButton("확인", skin);
        okButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                messageWindow.remove();
            }
        });
        messageWindow.add(okButton).pad(10);
        
        messageWindow.pack();
        messageWindow.setPosition(stage.getWidth() / 2 - messageWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - messageWindow.getHeight() / 2);
        messageWindow.setModal(true);
        stage.addActor(messageWindow);
    }
    
    // 닉네임 변경 실패 메시지
    private void showNicknameUpdateFailure() {
        Window messageWindow = new Window("오류", skin);
        messageWindow.add(new Label("닉네임 변경 중 오류가 발생했습니다.\n다시 시도해 주세요.", skin)).pad(20);
        messageWindow.row();
        
        TextButton okButton = new TextButton("확인", skin);
        okButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                messageWindow.remove();
            }
        });
        messageWindow.add(okButton).pad(10);
        
        messageWindow.pack();
        messageWindow.setPosition(stage.getWidth() / 2 - messageWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - messageWindow.getHeight() / 2);
        messageWindow.setModal(true);
        stage.addActor(messageWindow);
    }


    // 회원탈퇴 확인 팝업
    private void showDeleteAccountConfirmation() {
        Window confirmWindow = new Window("회원탈퇴", skin);
        confirmWindow.setModal(true);
        confirmWindow.setMovable(false);
        confirmWindow.setResizable(false);
        
        confirmWindow.add(new Label("정말 회원탈퇴 하시겠습니까?", skin)).pad(20);
        confirmWindow.row();
        
        Table buttonTable = new Table();
        
        // 확인 버튼
        TextButton confirmButton = new TextButton("확인", skin);
        confirmButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                deleteUserAccount();
            }
        });
        
        // 취소 버튼
        TextButton cancelButton = new TextButton("취소", skin);
        cancelButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                confirmWindow.remove();
            }
        });
        
        buttonTable.add(confirmButton).pad(10);
        buttonTable.add(cancelButton).pad(10);
        
        confirmWindow.add(buttonTable);
        confirmWindow.pack();
        confirmWindow.setPosition(stage.getWidth() / 2 - confirmWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - confirmWindow.getHeight() / 2);
        stage.addActor(confirmWindow);
    }
    // 사용자 계정 삭제
    private void deleteUserAccount() {
        Preferences prefs = Gdx.app.getPreferences("GamePreferences");
        String userId = prefs.getString("userId", null);
        
        if (userId != null) {
            // Firebase에서 사용자 데이터 삭제 (새로운 deleteData 메서드 사용)
            firebaseService.deleteData("users/" + userId, new FirebaseCallback<Void>() {
                @Override
                public void onSuccess(Void result) {
                    //Gdx.app.log("Firebase", "사용자 데이터가 성공적으로 삭제되었습니다.");
                    Gdx.app.postRunnable(() -> {
                        showDeleteSuccessMessage();
                        remove(); // 메뉴 팝업 닫기
                    });
                }
                
                @Override
                public void onFailure(Exception e) {
                    //Gdx.app.error("Firebase", "사용자 데이터 삭제 실패: " + e.getMessage());
                    Gdx.app.postRunnable(() -> showDeleteFailureMessage());
                }
            });
        }
        
        // 로컬 데이터 삭제
        prefs.clear();
        prefs.flush();
    }
    
    private void showDeleteSuccessMessage() {
        Window messageWindow = new Window("회원탈퇴 완료", skin);
        messageWindow.add(new Label("회원탈퇴가 완료되었습니다.", skin)).pad(20);
        messageWindow.row();
        
        TextButton okButton = new TextButton("확인", skin);
        okButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                messageWindow.remove();
                Gdx.app.exit(); // 게임 종료
            }
        });
        messageWindow.add(okButton).pad(10);
        
        messageWindow.pack();
        messageWindow.setPosition(stage.getWidth() / 2 - messageWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - messageWindow.getHeight() / 2);
        messageWindow.setModal(true);
        stage.addActor(messageWindow);
    }
    
    private void showDeleteFailureMessage() {
        Window messageWindow = new Window("오류", skin);
        messageWindow.add(new Label("회원탈퇴 중 오류가 발생했습니다.\n나중에 다시 시도해 주세요.", skin)).pad(20);
        messageWindow.row();
        
        TextButton okButton = new TextButton("확인", skin);
        okButton.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                messageWindow.remove();
            }
        });
        messageWindow.add(okButton).pad(10);
        
        messageWindow.pack();
        messageWindow.setPosition(stage.getWidth() / 2 - messageWindow.getWidth() / 2, 
                                 stage.getHeight() / 2 - messageWindow.getHeight() / 2);
        messageWindow.setModal(true);
        stage.addActor(messageWindow);
    }
    
    // 사용자 점수 데이터를 담는 클래스
    private static class UserScore {
        String userId;
        String username;
        Integer score;
        
        UserScore(String userId, String username, Integer score) {
            this.userId = userId;
            this.username = username;
            this.score = score;
        }
    }
}
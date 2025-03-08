package io.github.chw3021.companydefense.stage;

import java.util.HashMap;
import java.util.Map;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Dialog;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.firebase.FirebaseCallback;
import io.github.chw3021.companydefense.firebase.FirebaseService;
import io.github.chw3021.companydefense.screens.MainViewScreen;


public class WaveManager {
    private Array<Wave> waves;
    private Stage uiStage;
    private int currentWaveIndex;
    private boolean waveInProgress = false; // 현재 웨이브 진행 상태
    private boolean gameOver;
    private boolean gameWon;
    private Game game;
    private FirebaseService firebaseService; // FirebaseService 추가
    private int score;

    public WaveManager(Stage uiStage, Game game, FirebaseService firebaseService) {
        waves = new Array<>();
        currentWaveIndex = 0;
        this.uiStage = uiStage;
        this.game = game;
        this.firebaseService = firebaseService; // FirebaseService 초기화
        this.score = 0; // 초기 점수 설정
    }

    public void addWave(Wave wave) {
        waves.add(wave);
    }

    public void startNextWave() {
        if (!waveInProgress && currentWaveIndex < waves.size) {
            waveInProgress = true; // 웨이브 시작
        }
    }

    public void update(float delta, StageParent stage) {
        if (gameOver || gameWon) return;

        if (waveInProgress && currentWaveIndex < waves.size) {
            Wave currentWave = waves.get(currentWaveIndex);

            if (!currentWave.isComplete()) {
                currentWave.execute(delta, stage.getActiveEnemies(), stage);
            } else {
                waveInProgress = false; // 웨이브 종료
                currentWaveIndex++;
                score += 100;

                // 마지막 웨이브 체크
                if (currentWaveIndex >= waves.size) {
                    checkGameVictory(stage);
                }
            }
        }
    }
    public void checkGameVictory(StageParent stage) {
        if (gameWon || gameOver) return;
        if (stage.getActiveEnemies().isEmpty()) {
            gameWon = true;
            showEndPopup(true, stage);
        }
    }

    public void checkGameOver(StageParent stage) {
        if (gameWon || gameOver) return;
        if (stage.getLife() <= 0) {
            gameOver = true;
            showEndPopup(false, stage);
        }
    }
    
    public void render(float delta) {

        // UI Stage 갱신 및 렌더링
        uiStage.act(delta);
        uiStage.draw();
    }

    private void showEndPopup(boolean isWin, StageParent stage) {
        if (uiStage == null) {
            Gdx.app.log("WaveManager", "UI Stage is not set. Cannot show popup.");
            return;
        }

        // 보상 계산
        int goldReward = currentWaveIndex * 200;

        // 점수 계산
        int finalScore = score;

        // 팝업창 생성
        Skin skin = new Skin(Gdx.files.internal("ui/companyskin.json"));
        Dialog dialog = new Dialog(isWin ? "승리!" : "패배", skin);
        dialog.text("결과: " + (isWin ? "승리!" : "패배") + "\n획득 골드: " + goldReward + "\n점수: " + finalScore).pad(20);

        TextButton button = new TextButton("메인 화면", skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                // Firebase에 골드 지급 및 최고 점수 갱신
                Preferences prefs = Gdx.app.getPreferences("GamePreferences");
                String userId = prefs.getString("userId", null);
                if (userId != null) {
                    // 골드 지급

                    // 최고 점수 갱신
                    firebaseService.fetchData("users/" + userId + "/gold", Integer.class, new FirebaseCallback<Integer>() {
                        @Override
                        public void onSuccess(Integer gold) {
                            Map<String, Object> update = new HashMap<>();
                            update.put("users/" + userId+ "/gold", gold + (isWin ? goldReward*1.5 : goldReward));
                            firebaseService.updateData(update, new FirebaseCallback<Void>() {
                                @Override
                                public void onSuccess(Void unused) {
                                    Gdx.app.log("WaveManager", "gold s: " + goldReward);
                                }

                                @Override
                                public void onFailure(Exception e) {
                                    Gdx.app.error("WaveManager", "gold fail: " + e.getMessage());
                                }
                            });
                        }

                        @Override
                        public void onFailure(Exception e) {
                            Gdx.app.error("WaveManager", "userHighScore: " + e.getMessage());
                        }
                    });
                    
                    // 최고 점수 갱신
                    firebaseService.fetchData("users/" + userId + "/userHighScore", Integer.class, new FirebaseCallback<Integer>() {
                        @Override
                        public void onSuccess(Integer currentHighScore) {
                            if (currentHighScore == null || finalScore > currentHighScore) {
                                Map<String, Object> scoreUpdate = new HashMap<>();
                                scoreUpdate.put("users/" + userId + "/userHighScore", finalScore);
                                firebaseService.updateData(scoreUpdate, new FirebaseCallback<Void>() {
                                    @Override
                                    public void onSuccess(Void unused) {
                                        Gdx.app.log("WaveManager", "userHighScore: " + finalScore);
                                    }

                                    @Override
                                    public void onFailure(Exception e) {
                                        Gdx.app.error("WaveManager", "userHighScore: " + e.getMessage());
                                    }
                                });
                            }
                        }

                        @Override
                        public void onFailure(Exception e) {
                            Gdx.app.error("WaveManager", "userHighScore: " + e.getMessage());
                        }
                    });
                } else {
                    Gdx.app.error("WaveManager", "idnone.");
                }

                game.setScreen(new MainViewScreen(game));
                stage.dispose();
            }
        });
        dialog.button(button);

        dialog.setModal(true);
        dialog.setVisible(true);
        dialog.setZIndex(Integer.MAX_VALUE);
        dialog.show(uiStage);
    }


    
    public void setStage(Stage stage) {
    	uiStage = stage;
    }

    public boolean isGameOver() {
        return gameOver;
    }

    public boolean isGameWon() {
        return gameWon;
    }

    public void setFirebaseService(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
    }
}

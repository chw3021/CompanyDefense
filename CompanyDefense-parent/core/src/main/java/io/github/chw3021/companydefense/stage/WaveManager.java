package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Dialog;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.Main;
import io.github.chw3021.companydefense.menu.StageSelectionScreen;


public class WaveManager {
    private Array<Wave> waves;
    private Stage uiStage;
    private int currentWaveIndex;
    private float timeBetweenWaves = 30.0f;
    private float waveTransitionTimer;
    private boolean gameOver;
    private boolean gameWon;

    public WaveManager(Stage uiStage) {
        waves = new Array<>();
        currentWaveIndex = 0;
        waveTransitionTimer = 0;
        this.uiStage = uiStage;
    }

    public void addWave(Wave wave) {
        waves.add(wave);
    }

    public void update(float delta, StageParent stage) {
        if (gameOver || gameWon) return;

        if (currentWaveIndex < waves.size) {
            Wave currentWave = waves.get(currentWaveIndex);

            if (!currentWave.isComplete()) {
                currentWave.execute(delta, stage.getActiveEnemies(), stage);
            } else {
                waveTransitionTimer += delta;

                // Check if transition time is over
                if (waveTransitionTimer >= timeBetweenWaves) {
                    currentWaveIndex++;
                    waveTransitionTimer = 0;

                    // Check if this was the last wave
                    if (currentWaveIndex >= waves.size) {
                        checkGameVictory(stage);
                    }
                }
            }
        }
    }

    public void checkGameVictory(StageParent stage) {
        if (stage.getActiveEnemies().isEmpty()) {
            gameWon = true;
            showEndPopup(true, stage);
        }
    }

    public void checkGameOver(StageParent stage) {
        if (stage.getLife() <= 0) {
            gameOver = true;
            showEndPopup(false, stage);
        }
    }

    // 승리 또는 패배 팝업창 표시
    private void showEndPopup(boolean isWin, StageParent stage) {
        if (uiStage == null) {
            Gdx.app.log("WaveManager", "UI Stage is not set. Cannot show popup.");
            return;  // uiStage가 null인 경우 팝업을 표시하지 않음
        }
        // 팝업창 생성
        Skin skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        Dialog dialog = new Dialog(isWin ? "Victory!" : "Defeat", skin);
        dialog.text(isWin ? "Congratulations! You win!" : "Game Over! You lose.")
              .pad(20); // 패딩 추가로 텍스트 간격 조정
        dialog.button("Main Menu", new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                // 메인 화면으로 이동
                Main mainInstance = Main.getInstance();
                if (mainInstance != null) {
                    mainInstance.setScreen(new StageSelectionScreen(mainInstance));
                } else {
                    Gdx.app.error("WaveManager", "Main instance is null!");
                }
                stage.dispose();
            }
        });
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
}

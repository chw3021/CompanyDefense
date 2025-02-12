package io.github.chw3021.companydefense.stage;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Dialog;
import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.Array;

import io.github.chw3021.companydefense.screens.MainViewScreen;
import io.github.chw3021.companydefense.screens.gamescreens.StageSelectionScreen;


public class WaveManager {
    private Array<Wave> waves;
    private Stage uiStage;
    private int currentWaveIndex;
    private boolean waveInProgress = false; // 현재 웨이브 진행 상태
    private boolean gameOver;
    private boolean gameWon;
    private Game game;

    public WaveManager(Stage uiStage, Game game) {
        waves = new Array<>();
        currentWaveIndex = 0;
        this.uiStage = uiStage;
        this.game = game;
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

        // 팝업창 생성
        Skin skin = new Skin(Gdx.files.internal("ui/uiskin.json"));
        Dialog dialog = new Dialog(isWin ? "승리!" : "패배", skin);
        dialog.text(isWin ? "승리!" : "패배.").pad(20);

        TextButton button = new TextButton("메인 화면", skin);
        button.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
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
}

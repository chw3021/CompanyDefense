package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Image;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.utils.Align;
import com.badlogic.gdx.utils.Timer;
public class LoadingScreenManager {
    private Stage stage;
    private Table loadingTable;

    public LoadingScreenManager(Stage stage) {
        this.stage = stage;
    }
    public void testLoadingScreen() {
        showLoadingScreen();
        Label debugLabel = new Label("Loading...", new Label.LabelStyle(new BitmapFont(), Color.WHITE));
        loadingTable.add(debugLabel).center();
        stage.act(Gdx.graphics.getDeltaTime());
        stage.draw();
        System.out.println("arfdasf");

        Timer.schedule(new Timer.Task() {
            @Override
            public void run() {
                System.out.println("555");
                Gdx.app.postRunnable(() -> hideLoadingScreen());
            }
        }, 3); // 3초 후 hideLoadingScreen 실행
    }
    // 로딩 화면 보여주기
    public void showLoadingScreen() {
        loadingTable = new Table();
        loadingTable.setFillParent(true);
        stage.addActor(loadingTable);

        try {
            Texture loadingTexture = new Texture(Gdx.files.internal("icons/loading.png"));
            Image rotatingImage = new Image(loadingTexture);
            rotatingImage.setOrigin(Align.center);
            loadingTable.add(rotatingImage).center().size(100, 100); // 크기 조정
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // 로딩 화면 숨기기
    public void hideLoadingScreen() {
        if (loadingTable != null) {
            loadingTable.remove();
        }

        // 원래 화면 색상 복구
        stage.getBatch().setColor(1f, 1f, 1f, 1f); // 색상 복구
    }
}

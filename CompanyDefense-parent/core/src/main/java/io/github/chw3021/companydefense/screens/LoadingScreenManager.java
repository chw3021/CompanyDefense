package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Image;

import io.github.chw3021.companydefense.screens.imagetools.PngAnimation;

public class LoadingScreenManager {
    private Stage stage;
    private PngAnimation loadingImage; // PNG 애니메이션
    private Image backgroundOverlay; // 반투명 배경
    private boolean isLoadingScreenVisible = false; // 로딩 화면 상태 체크

    public LoadingScreenManager(Stage stage) {
        this.stage = stage;
        preloadLoadingElements();
    }

    private void preloadLoadingElements() {
        Gdx.app.postRunnable(() -> {
            try {
                float imageSize = Gdx.graphics.getWidth() * 0.1f;
                
                // 💡 로딩 애니메이션
                String spriteSheetPath = "icons/loading.png";
                int frameWidth = 640;
                int frameHeight = 640;

                loadingImage = new PngAnimation(0.1f, spriteSheetPath, frameWidth, frameHeight, true);
                loadingImage.setSize(imageSize, imageSize);

                // 화면 중앙 배치
                float centerX = (Gdx.graphics.getWidth() - loadingImage.getWidth()) / 2;
                float centerY = (Gdx.graphics.getHeight() - loadingImage.getHeight()) / 2;
                loadingImage.setPosition(centerX, centerY);

                // 💡 반투명 배경 (검은색, 50% 투명도)
                Pixmap pixmap = new Pixmap(1, 1, Pixmap.Format.RGBA8888);
                pixmap.setColor(0, 0, 0, 0.8f); // 투명도 조절 (0.5f = 50%)
                pixmap.fill();

                Texture texture = new Texture(pixmap);
                pixmap.dispose();

                backgroundOverlay = new Image(texture);
                backgroundOverlay.setSize(Gdx.graphics.getWidth(), Gdx.graphics.getHeight());
                backgroundOverlay.setPosition(0, 0);

            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    public void showLoadingScreen() {
        Gdx.app.postRunnable(() -> {
            if (!isLoadingScreenVisible) {
                stage.addActor(backgroundOverlay); // 💡 배경 먼저 추가
                stage.addActor(loadingImage); // 💡 로딩 애니메이션 추가
                isLoadingScreenVisible = true;
            }
        });
    }

    public void hideLoadingScreen() {
        Gdx.app.postRunnable(() -> {
            if (isLoadingScreenVisible) {
                backgroundOverlay.remove(); // 💡 배경 제거
                loadingImage.remove(); // 💡 애니메이션 제거
                isLoadingScreenVisible = false;
            }
        });
    }
}


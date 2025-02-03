package io.github.chw3021.companydefense.screens;

import com.badlogic.gdx.Gdx;

import com.badlogic.gdx.scenes.scene2d.Stage;
import io.github.chw3021.companydefense.screens.imagetools.PngAnimation;

public class LoadingScreenManager {
    private Stage stage;
    private PngAnimation loadingImage; // PNG 애니메이션

    public LoadingScreenManager(Stage stage) {
        this.stage = stage;
        preloadLoadingElements();
    }

    private void preloadLoadingElements() {
        Gdx.app.postRunnable(() -> {
            try {
                float imageSize = Gdx.graphics.getWidth() * 0.1f;
                
                // 스프라이트 시트 사용 (3200x6400에서 5개의 프레임 추출)
                String spriteSheetPath = "icons/loading.png";
                int frameWidth = 640;  // 640px
                int frameHeight = 640;  // 6400px (하나의 줄에 5개 프레임)

                loadingImage = new PngAnimation(0.1f, spriteSheetPath, frameWidth, frameHeight, true);
                loadingImage.setSize(imageSize, imageSize);

                // 화면 중앙 배치
                float centerX = (Gdx.graphics.getWidth() - loadingImage.getWidth()) / 2;
                float centerY = (Gdx.graphics.getHeight() - loadingImage.getHeight()) / 2;
                loadingImage.setPosition(centerX, centerY);

            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }

    public void showLoadingScreen() {
        Gdx.app.postRunnable(() -> {
            if (loadingImage != null && !loadingImage.hasParent()) {
                stage.addActor(loadingImage);
            }
        });
    }

    public void hideLoadingScreen() {
        Gdx.app.postRunnable(() -> {
            if (loadingImage != null) {
                loadingImage.remove();
            }
        });
    }
}

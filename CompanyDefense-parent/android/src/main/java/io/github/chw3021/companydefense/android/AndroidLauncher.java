package io.github.chw3021.companydefense.android;

import android.os.Bundle;

import com.badlogic.gdx.backends.android.AndroidApplication;
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration;
//import com.google.firebase.FirebaseApp;

import io.github.chw3021.companydefense.Main;
//import io.github.chw3021.companydefense.android.firebase.AndroidFirebaseService;
//import io.github.chw3021.companydefense.firebase.FirebaseService;

/** Launches the Android application. */
public class AndroidLauncher extends AndroidApplication {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        //FirebaseApp.initializeApp(this);
        // 반드시 Context를 전달해야 함
       // FirebaseService firebaseService = new AndroidFirebaseService();


        AndroidApplicationConfiguration configuration = new AndroidApplicationConfiguration();
        configuration.useImmersiveMode = true; // Recommended, but not required.
        initialize(new Main(), configuration);


        //initialize(new Main(firebaseService), configuration);
    }

}

/*
 * Art-Net to PixelPusher bridge application written by Tom Shea.
 * Broadcast Art-Net to localhost in Resolume.
 * Run this program to receive Art-Net, translate it to PixelPusher, and send it out to the network.
 * There are exactly 170 pixels per Lumiverse - please map accordingly.
 * All pixels reported by the PixelPushers must be accounted for in the mapping.
 * PixelPushers must be configured with correctly-ordered group/controller ordinals to correspond to the correct ArtNet Universes.
 * Do not configure the PixelPushers to use Art-Net themselves!
 */

import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;
import com.heroicrobot.dropbit.devices.pixelpusher.PixelPusher;
import com.heroicrobot.dropbit.devices.pixelpusher.PusherCommand;
import ch.bildspur.artnet.*;

import java.util.*;

DeviceRegistry registry;
TestObserver testObserver;

ArtNetClient artNet;

ArrayList<ArtNetUniverse> ArtNetUniverses;
int universeCount;

class ArtNetUniverse {
  byte[] data;

  ArtNetUniverse() {
    data = new byte[512];
  }

  int getPixelColor(int index) {
    return color(data[index * 3] & 0xFF, data[index * 3 + 1] & 0xFF, data[index * 3 + 2] & 0xFF);
  }
}

class TestObserver implements Observer {
  public boolean hasStrips = false;
  public void update(Observable registry, Object updatedDevice) {
    println("Registry changed!");
    if (updatedDevice != null) {
      println("Device change: " + updatedDevice);
    }
    this.hasStrips = true;
  }
}

void setup() {  
  //size(640, 640, P3D);
  size(40, 40);
  universeCount = 0;
  ArtNetUniverses = new ArrayList<ArtNetUniverse>();
  artNet = new ArtNetClient();
  artNet.start();

  registry = new DeviceRegistry();
  testObserver = new TestObserver();
  registry.addObserver(testObserver);
  registry.startPushing();
  registry.setExtraDelay(0);
  //registry.setAutoThrottle(true);
  registry.setAntiLog(true);

  frameRate(60);
  prepareExitHandler();
}

void draw() {
  if (testObserver.hasStrips) {  
    List<Strip> strips = registry.getStrips();    
    int totalPixels = 0;
    for (Strip strip : strips) {
      totalPixels += strip.getLength();
    }
    int universeCountNew = ceil(totalPixels / 170.0);
    if (universeCountNew != universeCount) {
      universeCount = universeCountNew;
      ArtNetUniverses.clear();
      for (int i = 0; i < universeCount; i++) {
        ArtNetUniverses.add(new ArtNetUniverse());
      }
    }

    for (int i = 0; i < universeCount; i++) {
      ArtNetUniverses.get(i).data = artNet.readDmxData(0, i);
    }

    //registry.startPushing();
    //registry.setExtraDelay(0);
    //registry.setAutoThrottle(true);
    //registry.setAntiLog(true);

    int numStrips = strips.size();
    if (numStrips == 0)
      return;

    int pixelIncrementor = 0;
    for (Strip strip : strips) {
      for (int address = 0; address < strip.getLength(); address++) {
        int universe = floor(pixelIncrementor / 170.0);
        color c = ArtNetUniverses.get(universe).getPixelColor(pixelIncrementor % 170);
        strip.setPixel(c, address);
        pixelIncrementor++;
      }
    }
  }
}

private void prepareExitHandler () {

  Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {

    public void run () {

      System.out.println("Shutdown hook running");

      List<Strip> strips = registry.getStrips();
      for (Strip strip : strips) {
        for (int i = 0; i < strip.getLength(); i++)
        strip.setPixel(#000000, i);
      }
      for (int i = 0; i < 100000; i++)
      Thread.yield();
    }
  }
  ));
}

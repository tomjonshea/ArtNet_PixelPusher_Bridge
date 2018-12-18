/*
 * Art-Net to PixelPusher bridge application written by Tom Shea.
 * Broadcast Art-Net to localhost in Resolume.
 * Run this program to receive Art-Net, translate it to PixelPusher, and send it out to the network.
 * This program splits every PP strip evenly across two Art-Net universes.
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
    //println("Registry changed!");
    if (updatedDevice != null) {
      //println("Device change: " + updatedDevice);
    }
    this.hasStrips = true;
  }
}

void setup() {  
  //size(640, 640, P3D);
  size(1200, 640);
  textAlign(LEFT, CENTER);
  textSize(15);

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
  try {
    if (testObserver.hasStrips) {  
      List<Strip> strips = registry.getStrips(); 
      int numStrips = strips.size();
      int totalPixels = 0;
      for (Strip strip : strips) {
        totalPixels += strip.getLength();
      }
      //int universeCountNew = ceil(totalPixels / 170.0);
      int universeCountNew = numStrips * 2;
      if (universeCountNew != universeCount) {
        universeCount = universeCountNew;
        ArtNetUniverses.clear();
        for (int i = 0; i < universeCount; i++) {
          ArtNetUniverses.add(new ArtNetUniverse());
        }
        background(color(128, 128, 128));
        text("Total Art-Net Universes: " + universeCount, width / 30, height / 30);
        text("Total Art-Net Pixels: " + universeCount * 170, width / 30, 2 * height / 30);
        text("Total PP Strips Count: " + numStrips, width / 30, 3 * height / 30);
        text("Total PP Pixels Count: " + totalPixels, width / 30, 4 * height / 30);
        List<PixelPusher> pushers = registry.getPushers();
        int pusherIterator = 0;
        int stripIterator = 0;
        int pusherCount = pushers.size();
        text("Total PixelPushers Count: " + pusherCount, width / 30, 5 * height / 30);
        for (PixelPusher pusher : pushers) {
          text("PixelPusher ID: " + pusher.getControllerOrdinal() + 
            "     Group: " + pusher.getGroupOrdinal() + 
            "     Strips Attached: " + pusher.getNumberOfStrips() + 
            "     Pixels Per Strip: " + pusher.getPixelsPerStrip() +
            "     Total Pixels: " + pusher.getPixelsPerStrip() * pusher.getNumberOfStrips() + 
            "     IP: " + pusher.getIp() +
            "     Universes: " + (stripIterator * 2) + 
            "-" + ((stripIterator + pusher.getNumberOfStrips()) * 2 - 1) + 
            " (" + pusher.getNumberOfStrips() * 2 + " total)",
            width / 30, (7+ pusherIterator) * height / 30);
          pusherIterator++;
          stripIterator += pusher.getNumberOfStrips();
        }
      }

      for (int i = 0; i < universeCount; i++) {
        ArtNetUniverses.get(i).data = artNet.readDmxData(floor(i / 16), i % 16);
      }

      //registry.startPushing();
      //registry.setExtraDelay(0);
      //registry.setAutoThrottle(true);
      //registry.setAntiLog(true);


      if (numStrips == 0)
        return;

      //int pixelIncrementor = 0;
      int stripIncrementor = 0;
      for (Strip strip : strips) {
        int stripUniverse = 0;
        for (int address = 0; address < strip.getLength(); address++) {
          //int universe = floor(pixelIncrementor / 170.0);
          if (address >= strip.getLength()/2) stripUniverse = 1;
          int pixelId = (stripUniverse == 1) ? address - strip.getLength()/2 : address;
          //color c = ArtNetUniverses.get(stripIncrementor * 2 + stripUniverse).getPixelColor(pixelIncrementor % 170);
          color c = ArtNetUniverses.get(stripIncrementor * 2 + stripUniverse).getPixelColor(pixelId);
          //strip.setPixel(c, address);
          strip.setPixel(c, address);
          //pixelIncrementor++;
        }
        stripIncrementor++;
      }
    }
  } 
  catch (Exception e) {
    return;
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

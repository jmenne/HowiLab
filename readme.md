# HowiLab

---

## Schulungs-, Demo-, Testumgebung auf Basis von Hyper-V

Du benötigst hin und wieder eine Testumgebung bestehend aus einem DC, einem Client und einem Server zu Schulungszwecken, selbstlernen oder experimentieren?

## Hardwarevoraussetzungen

Benötigt wird ein Windows PC mit Hyper-V, entweder Windows 10 oder ein Serverbetriebssystem. Eine SSD ist aus Performancegründen sehr empfehlenswert und ausreichend Arbeitsspeicher sollte vorhanden sein (16 GB oder mehr wären optimal).

## Benötigte Dateien

Das Powershell-Skript zum erstellen der VMs braucht Basis Images der gewünschten Betriebssysteme, da die VMs mit differenzierenden Festplatten erstellt werden.  
Dazu müssen die Dateien BaseServer2012.vhd(x), BaseServer2016.vhd(x), BaseServer2019.vhd(x), BaseW81.vhd(x) und BaseW10.vhd(x) im Unterordner &lt;Laufwerksbuchstabe&gt;:\\vms\\howi-lab\\Base\\ liegen. Hierbei sollte es sich um "gesyspreppte" Betriebssysteme mit aktuellen Sicherheitsupdates handeln.  
Diese lassen sich z.B. mithilfe des Microsoft Deployment Toolkit (MDT) erstellen. Wie das geht beschreibt Johan Arwidmark in seinem [Blog](https://deploymentresearch.com/Research/Post/1676/Building-a-Windows-10-v1809-reference-image-using-Microsoft-Deployment-Toolkit-MDT) sehr ausführlich. Als Ergebnis bekommt man eine .wim Datei. Diese .wim Datei muss man dann noch in eine .vhd(x) umwandeln. Das erledigt das Powershell Skript **Convert-WindowsImage.ps1**, welches auf dem Server 2016 Installationsmedium im Ordner NanoServer\\NanoServerImageGenerator oder [hier](https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f) zu finden ist.

```powershell
. .\Convert-WindowsImage.ps1
# vhd Images für Gen1 Maschinen
Convert-WindowsImage -SourcePath .\REFW10X64.wim -edition 1 -vhdpath q:\wim2vhd\BaseW10.vhd -VHDFormat vhd -disklayout BIOS -UnattendPath Q:\vms\unattend.xml

# vhdx Images für Gen2 Maschinen
Convert-WindowsImage -SourcePath .\REFW10X64.wim -Edition 1 -VHDPath Q:\wim2vhd\BaseW10.vhdx -VHDFormat VHDX -DiskLayout UEFI -UnattendPath Q:\vms\unattend.xml
```

Will man Generation-1 VMs erstellen, benötigt man .vhd Images.  
Will man statttdessen Generation-2 VMs, benötigt man .vhdx Images.  
Durch die *unattend.xml* wird für das integrierte Administrator Konto das Kennwort **Pa$$w0rd** vorgegeben.  
Die **LiteTouchMedia.iso** muss man sich separat [hier](https://1drv.ms/u/s!AsFZQvazEgntgu93nnfuGs4JMov5DA) herunterladen, da sie für GitHub zu groß ist.

## Erstellen der Umgebung

### Schritt 1: Erstellen der virtuellen Maschinen

Nachdem man alle Dateien an die richtige Stelle kopiert hat, dienen die Skripte **CreateGen1VMs_Menu.ps1** zum erstellen vom VMs der Generation-1 und **CreateGen2VMs_Menu.ps1** zum erstellen von Maschinen der Generation-2. Zum Ausführen das passende Skript mit der rechten Maustaste anklicken und aus dem Kontextmenü *Mit PowerShell ausführen* wählen.  
Es werden zwei private virtuelle Switche mit den Namen *Corpnet* und *Inet* erstellt.  
Sodann wählt man aus, welchen DC, App und Client man haben möchte und drückt abschließend *F* für fertig.  
Zum Abschluß deaktiviert das Skript *Automatische Prüfpunkte verwenden* auf einem Windows 10 Hyper-V Host Rechner.

### Schritt 2: Konfigurieren der virtuellen Maschinen

#### DC vorbereiten

Starte als Erstes den DC und melde dich als *Administrator* an. Im DVD-Laufwerk befindet sich die *"&lt;Laufwerksbuchstabe&gt;:\vms\LiteTouchMedia.iso"*. Diese über den VM-Connect Menüpunkt *Medien, DVD-Laufwerk, Auswerfen* entfernen (Bild01) und über den gleichen Weg wieder einlegen (Bild02 und Bild03). Das ist erforderlich, damit der Autostart der DVD funktioniert (Bild04). In der VM dann den *Windows Deployment Wizard* ausführen (Bild05 und Bild06). 
![Bild01](/Bilder/Bild01.png)
**Bild01**
![Bild02](/Bilder/Bild02.png)
**Bild02**
![Bild03](/Bilder/Bild03.png)
**Bild03**
![Bild04](/Bilder/Bild04.png)
**Bild04**
![Bild05](/Bilder/Bild05.png)
**Bild05**
![Bild06](/Bilder/Bild06.png)
**Bild06**
Im nun erscheinenden Fenster die zur VM passende Tasksequenz (DC01, DC02 oder DC03) auswählen (Bild07).
![Bild07](/Bilder/Bild07.png)
**Bild07**  
Der Server wird nun zu einem DC für die Domäne *corp.howilab.local* und auch zum DHCP-Server für die Domäne. Nachdem die Tasksequenz beendet ist, die Warnungen des Servermanagers bearbeiten (Assistent zum Hochstufen des DCs und Abschluss der DHCP-Bereitstellung).

#### App und Client

Wenn der DC fertig ist und läuft, die anderen VMs starten. Hier ebenfalls, wie oben beschrieben, die DVD auswerfen, wieder einlegen, *Windows Deployment Wizard* ausführen, passende Tasksequenz auswählen.  
Der APP Server wird Domänenmitglied, der IIS installiert, sowie eine Freigabe *"c:\\files"* erstellt.  
(Hinweis: Manchmal funktioniert das Aufnehmen in die Domäne nicht!)  
Der Client wird Domänenmitglied.
Nach dem Neustart der VMs, kann man sich als *corp\Administrator* an der Domäne anmelden.

## Internetkonnektivität für die VMs

Erst ab Windows 10 und Server 2016 lässt sich in Hyper-V ein NatSwitch erstellen, um den VMs eine Verbindung ins Internet zu ermöglichen. Hierzu kann man das Powershell-Skript **NatSwitch.ps1** verwenden. Anschließend ALLE VMs vom Switch *Corpnet* an den *NatSwitch* hängen.  
Ist man auf einem älteren Hyper-V Host unterwegs, kann man nur eine zusätzliche VM, z.B. Edge01, als Router konfigurieren.

## Los geht's  

Diese Umgebung kann nun als Ausgangspunkt für eigene Projekte verwendet werden. Als Beispiel ist im Ordner *Projekte\\HV-Cluster\\* ein Skript zum erstellen eines Failoverclusters mit zwei Hyper-V Hosts enthalten.  
Weitere Ideen und deren Umsetzung sind willkommen...

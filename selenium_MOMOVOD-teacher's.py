# -*- coding: utf-8 -*-
"""
Created on Fri Nov 24 10:38:10 2023

@author: clark

no session protection
"""
from selenium import webdriver
from selenium.webdriver.common.by import By
#from IPython.display import Image,display
from PIL import Image  as PILIMG        
import requests
from io import BytesIO
import time
import sqlite3
def execSQLcommand(sqlstr):
    global myConn
    global myCursor
    try:
      myCursor = myConn.execute(sqlstr)
      myConn.commit()
      print("指令已成功執行:" + sqlstr)
      return myCursor
    except:
      print("指令有誤:", sqlstr)
      
def downloadimg(imgurl, img_name): #imgurl為下載圖檔的網址, img_name為下載的路徑與檔名
    urlcontent = requests.get(imgurl) # use 'get' to get photo link path , requests = send request
    with open(img_name,'wb') as file: #以byte的形式將圖片數據寫入
         file.write(urlcontent.content)
         file.flush() #即將緩衝區中的資料立刻寫入檔,一般情況下，檔關閉後才會自動刷新緩衝區;這裡離開with 就會close, 所以file.close()可省略
         file.close() 
         print('已儲存' + img_name)
myConn = sqlite3.connect(r"D:\2023_Python\Exercise\selenium\mydb.db")
myCursor = myConn.cursor()
def getdata():

    myweb = webdriver.Edge(r"D:\2023_Python\我的範例\msedgedriver.exe")  
    
    execSQLcommand('delete from movie;')
    
    url = "https://momovod.app/type/1.html"
    flag_go = 1
    pageNo = 1 
    moviecount = 0
    while flag_go:
       
        myweb.get(url)
        mainwin = myweb.window_handles[0]
        print('============================')
       
      
        time.sleep(3)
        alldiv = myweb.find_elements(By.CSS_SELECTOR,".col-lg-6.col-md-6.col-sm-6.col-xs-3")
        #alldiv = myweb.find_elements.by_css_selen
        
       
        for item in alldiv:
            try:
                    #print(item)
                    #h4=item.find_element(By.CSS_SELECTOR,'.title.text-overflow')   
                    moviecount += 1
                    nextURL = item.find_element(By.CSS_SELECTOR,'.myui-vodlist__thumb.lazyload').get_attribute('href')
                    newwin = myweb.switch_to.new_window('tab')
                    myweb.get(nextURL)
                    time.sleep(1)
                    #片名
                    mvtitle = ''
                    mvtitle = myweb.find_element(By.CLASS_NAME,'title').text
                    datalist = myweb.find_elements(By.CLASS_NAME,"data")
                    datalist1_aList = datalist[0].find_elements(By.TAG_NAME,'a')
                    #分類
                    mvclass = ''
                    mvclass = datalist1_aList[0].text
                    #地區
                    mvarea=''
                    mvarea = datalist1_aList[1].text
                    #年分
                    mvyear = ''
                    mvyear = datalist1_aList[2].text
                    #演員
                    actorList = ''
                    actorList = datalist[1].text.replace('主演：','')
                    #
                    print('title:', mvtitle)
                    print('class:', mvclass)
                    print('area:', mvarea)
                    print('actor:', actorList)
                    sql = "insert into movie(mv_id, title,actor, area, class, year)values("
                    sql += str(moviecount) + ','
                    sql += "'" + mvtitle + "',"
                    sql += "'" + actorList + "',"
                    sql += "'" + mvarea + "',"
                    sql += "'" + mvclass + "',"
                    sql += "'" + mvyear + "')"
                    
                    print('-----')
                    print(sql)
                    print('-----')
                    execSQLcommand(sql)
                    myweb.close()
                    myweb.switch_to.window(mainwin)
                    #thisImg = item.find_element(By.TAG_NAME,'a').get_attribute('data-original')
                    #print('src:',thisImg)
                    
                    #method1  URL
                    #from IPython.display import Image,display
                    #try:
                    # display(Image(requests.get(thisImg).content))  #byte like content
                    #except:
                    # print("Can't find picture")
                        
                    
                    #method2  Local
                    ##from PIL import Image  as PILIMG
                    #imgName = 'img' + str(pageNo) + '_' + str(count) + '.jpg'
                    #downloadimg(thisImg, imgName)
                    #shownimg = PILIMG.open(imgName)
                    #shownimg.show()
                    #----
                    #method 3
                    #urlImgContent = requests.get(thisImg) 
                    #urlImage = Image.open(BytesIO(requests.get(thisImg).content ))  ##byte like content
                    #urlImage.show()
                    
                    print('---')
            except:
                    print('Error')
                   #myweb.quit()  
                #------------------------    
                #next page
        tag_nextPage = myweb.find_elements(By.PARTIAL_LINK_TEXT,'下一頁')
        if len(tag_nextPage) != 0:  
           nextPageURL =  str(tag_nextPage[0].get_attribute("href"))
           if url != nextPageURL:
              url =  nextPageURL
              pageNo += 1
           else:
              break;
        else:
              break;
       
def getplot():
    sql = "select area, class , count(*) "
    sql += " from movie"
    sql += " where area in('中國大陸', '日本', '美國')"
    sql += " group by area, class"
    dbdata = myCursor.execute(sql).fetchall()
    myConn.commit()
    listcount = []
    listarea = []
    listclass = []
    for item in dbdata:
        
        listarea.append(item[0])
        listclass.append(item[1])
        listcount.append(item[2])
        print(item)
        print('-------------')
        
    from matplotlib import pyplot as plt
    import matplotlib.font_manager as fm
    
    fpath = "C:\Windows\Fonts\kaiu.ttf"
    prop = fm.FontProperties(fname=fpath)
    plt.figure(figsize=(30,10))#(寬,高)
    
    
    area = listarea[0] #設定初始
    areagroup=[];areax=[]
    classgroup = []
    countgroup=[]
    
    listresult = []
    #groupid = 1
    axis = 1
    xticklist_new = []
    xticklist_old = []
    for idx in range(0,len(listarea)):
        if listarea[idx] == area:
            areagroup.append(area) # area
            xticklist_new.append(area)
            xticklist_old.append(axis)
            areax.append(axis); 
            axis += 0.5
            classgroup.append(listclass[idx])
            countgroup.append(listcount[idx])
        else:

            listresult.append([areagroup,areax,classgroup,countgroup])

            area =   listarea[idx]

            areax = [];  axis += 1; areax.append(axis); 
            axis += 0.5
            print('area:', area)
            print('axis:', axis)
            xticklist_new.append(area)
            xticklist_old.append(axis)
            
            areagroup = []; areagroup.append(area) 
            classgroup= []; classgroup.append(listclass[idx])
            countgroup=[];countgroup.append(listcount[idx])

    if len(areagroup) > 0:
       listresult.append([areagroup,areax,classgroup,countgroup])
            

    
    for idx in range(len(listresult)):
        print('**********************')
        print(listresult[idx])
        print('**********************')
        
        plt.bar(listresult[idx][1], listresult[idx][3], width=0.5,edgecolor='white',linewidth=2)
        
        for pos in range(len(listresult[idx][0])):
            if pos ==0: #寫群組名稱
               plt.text(listresult[idx][1][0], -2, listresult[idx][0][0] ,ha='center', va='bottom', fontsize=20, color='black',fontproperties=prop) 
            if pos % 2 == 0:
               plt.text(listresult[idx][1][pos], listresult[idx][3][pos]+0.1, listresult[idx][2][pos] + ":" + str(listresult[idx][3][pos]),ha='center', va='bottom', fontsize=10, color='red',fontproperties=prop)
            else:
                plt.text(listresult[idx][1][pos], listresult[idx][3][pos]+0.3, listresult[idx][2][pos] + ":" + str(listresult[idx][3][pos]),ha='center', va='bottom', fontsize=12, color='blue',fontproperties=prop)
        
    #除掉重複的tick / 會排序
    '''
    print('old', xticklist_old)
    print('new', xticklist_new)

    tick = xticklist_new[0]
    for idx in range(1,len(xticklist_new)):
        print('-->',xticklist_new[idx])
        if xticklist_new[idx] == tick:
           xticklist_new[idx] = '-'
        else:
           tick = xticklist_new[idx]
           xticklist_new[idx] == tick
        print('new', xticklist_new)
    
    '''
    plt.tick_params(
axis='x', # changes apply to the x-axis
which='both', # both major and minor ticks are affected
bottom=False, # ticks along the bottom edge are off
top=False, # ticks along the top edge are off
labelbottom=False) # labels along the bottom edge are off
    #plt.xticks(xticklist_old, xticklist_new, fontsize=15,fontproperties=prop)
    
#----------------------------------    
#getdata()
getplot()
myConn.close()

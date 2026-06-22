const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: '帅斌饼干远程控制台',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  // 加载本地前端页面
  win.loadFile(path.join(__dirname, 'src', 'index.html'));

  // 开发时打开开发者工具
  // win.webContents.openDevTools();
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

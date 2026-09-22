import {defineConfig,devices} from "@playwright/test";
export default defineConfig({testDir:"./e2e",fullyParallel:true,use:{baseURL:process.env.PLAYWRIGHT_BASE_URL??"http://127.0.0.1:3000",trace:"on-first-retry"},projects:[{name:"desktop",use:{...devices["Desktop Chrome"]}},{name:"mobile",use:{...devices["iPhone 13"]}}]});

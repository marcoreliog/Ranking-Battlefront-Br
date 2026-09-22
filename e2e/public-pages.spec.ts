import {test,expect} from "@playwright/test";
// Execute against a configured local/staging Supabase project (PLAYWRIGHT_BASE_URL).
test("ranking principal é navegável",async({page})=>{await page.goto("/");await expect(page.getByRole("heading",{name:/ranking geral/i})).toBeVisible();await expect(page.getByRole("link",{name:"Heróis"})).toBeVisible();});
test("interface principal se adapta a mobile",async({page})=>{await page.goto("/");await expect(page.locator("main")).toBeVisible();await expect(page.getByText(/classificação oficial/i)).toBeVisible();});

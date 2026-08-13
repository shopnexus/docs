#!/usr/bin/env node
/**
 * Chụp ảnh màn hình website ShopNexus đang chạy, phục vụ chương 5 báo cáo.
 *
 * Mọi thông tin đăng nhập đọc từ biến môi trường (xem .env.example) — KHÔNG ghi cứng.
 * Ảnh ghi vào docs/typst/common/assets/web/ với tên mô tả nội dung.
 *
 *   node capture-web-screenshots.mjs                # chụp tất cả
 *   node capture-web-screenshots.mjs --only=tim-kiem,thanh-toan
 *   node capture-web-screenshots.mjs --list         # xem danh sách bước
 *   node capture-web-screenshots.mjs --headed       # xem trình duyệt chạy
 *   node capture-web-screenshots.mjs --out=/tmp/x   # đổi thư mục ảnh
 */

import { createRequire } from "node:module";
import { mkdir, readdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");

// ---------------------------------------------------------------------------
// Playwright: dùng lại bản đã cài trong website/ nếu có, nếu không thì dùng bản
// cài cạnh script này (npm i -D @playwright/test trong docs/scripts/).
// ---------------------------------------------------------------------------
const require_ = createRequire(import.meta.url);
function loadPlaywright() {
	const candidates = [
		path.join(REPO, "website"), // đã có sẵn @playwright/test ở đây
		HERE,
	];
	for (const base of candidates) {
		try {
			return require_(require_.resolve("playwright", { paths: [base] }));
		} catch {
			/* thử chỗ tiếp theo */
		}
	}
	try {
		return require_("playwright");
	} catch {
		throw new Error(
			"Không tìm thấy Playwright. Chạy: cd docs/scripts && npm i -D @playwright/test && npx playwright install chromium",
		);
	}
}
const { chromium } = loadPlaywright();

// ---------------------------------------------------------------------------
// Cấu hình
// ---------------------------------------------------------------------------
const argv = process.argv.slice(2);
const flag = (name) => argv.some((a) => a === `--${name}`);
const value = (name, fallback) => {
	const hit = argv.find((a) => a.startsWith(`--${name}=`));
	return hit ? hit.slice(name.length + 3) : fallback;
};

const BASE_URL = (process.env.SHOPNEXUS_BASE_URL || "https://shopnexus.hopto.org").replace(/\/$/, "");
const OUT_DIR = value("out", path.join(REPO, "docs", "typst", "common", "assets", "web"));

const ACCOUNTS = {
	buyer: {
		id: process.env.SHOPNEXUS_BUYER_EMAIL,
		pw: process.env.SHOPNEXUS_BUYER_PASSWORD,
		envName: "SHOPNEXUS_BUYER_EMAIL / SHOPNEXUS_BUYER_PASSWORD",
	},
	seller: {
		id: process.env.SHOPNEXUS_SELLER_EMAIL,
		pw: process.env.SHOPNEXUS_SELLER_PASSWORD,
		envName: "SHOPNEXUS_SELLER_EMAIL / SHOPNEXUS_SELLER_PASSWORD",
	},
	// Tên đăng nhập, không phải email — biểu mẫu nhận email / SĐT / username.
	admin: {
		id: process.env.SHOPNEXUS_ADMIN_USERNAME,
		pw: process.env.SHOPNEXUS_ADMIN_PASSWORD,
		envName: "SHOPNEXUS_ADMIN_USERNAME / SHOPNEXUS_ADMIN_PASSWORD",
	},
};

/** Khung nhìn mặc định. Báo cáo quy định bề rộng tối thiểu 1440px. */
const VIEWPORT = { width: 1440, height: 900 };
const SCALE = 2;

// Dữ liệu thật trên môi trường thử — đổi ở đây nếu dữ liệu thay đổi.
const FIXTURES = {
	/** Từ khoá tiếng Việt không dấu, để minh hoạ tìm kiếm không dấu. */
	searchQuery: "ao thun nam",
	/** Tin đăng ở chế độ giá thương lượng. */
	negotiableListingId: "lst_6kydfg4dp6gxz",
	/** Nhãn trạng thái ưu tiên khi chọn đơn để chụp, xét theo thứ tự. Không ghim mã
	 *  đơn: mã được sinh lại sau mỗi lần nạp seed nên ghim là hỏng ngay lần sau. */
	orderStatePreference: [/Đang giao/i, /Hàng đã tới/i, /Đã giao/i],
	/** Nhãn ưu tiên khi chọn yêu cầu hoàn tiền để chụp. Không ghim mã: mã sinh lại
	 *  sau mỗi lần nạp seed, và trang lỗi vẫn chứa chữ "Yêu cầu hoàn tiền" nên một
	 *  mã chết KHÔNG làm script báo hỏng — nó chụp im lặng ra trang lỗi. */
	refundStatePreference: [/Chờ người bán/i, /Đang tranh chấp/i, /Đang trả hàng/i],
};

// ---------------------------------------------------------------------------
// Tiện ích

/**
 * Chọn một đơn trong danh sách theo nhãn trạng thái trên thẻ, trả về đường dẫn
 * chi tiết. Duyệt `preferences` theo thứ tự và lấy đơn khớp đầu tiên.
 */
async function pickHref(page, hrefFragment, preferences) {
	const cards = await page.$$eval(`a[href*="${hrefFragment}"]`, (as) => {
		const seen = new Set();
		const out = [];
		for (const a of as) {
			const href = a.getAttribute("href");
			if (!href || seen.has(href)) continue;
			seen.add(href);
			const box = a.closest("li,article,div[class]") || a;
			out.push({ href, text: box.innerText || "" });
		}
		return out;
	});
	if (!cards.length) throw new Error(`không thấy mục nào khớp ${hrefFragment}`);
	for (const re of preferences) {
		const hit = cards.find((c) => re.test(c.text));
		if (hit) return hit.href;
	}
	return cards[0].href;
}
// ---------------------------------------------------------------------------
const log = (...a) => console.log("·", ...a);

/** Đăng nhập bằng biểu mẫu thật, trả về page đã có phiên. */
async function signIn(browser, role, viewport = VIEWPORT) {
	const acc = ACCOUNTS[role];
	if (!acc.id || !acc.pw) {
		throw new Error(`Thiếu biến môi trường ${acc.envName} cho vai "${role}".`);
	}
	const context = await browser.newContext({
		viewport,
		deviceScaleFactor: SCALE,
		ignoreHTTPSErrors: true, // site tự ký / Let's Encrypt sau reverse proxy
		locale: "vi-VN",
		timezoneId: "Asia/Ho_Chi_Minh",
	});
	const page = await context.newPage();
	await page.goto(`${BASE_URL}/login`, { waitUntil: "domcontentloaded" });
	await page.fill("#identifier", acc.id);
	await page.fill("#password", acc.pw);
	await Promise.all([
		page.waitForURL((u) => !u.pathname.startsWith("/login"), { timeout: 45_000 }),
		page.click('button[type="submit"]'),
	]);
	await settle(page);
	log(`đăng nhập ${role} → ${page.url()}`);
	return page;
}

/**
 * Chờ trang thật sự yên: mạng rảnh, phông chữ nạp xong, mọi <img> đã giải mã.
 * Không có bước này thì ảnh dính khung xám placeholder và icon hiện ra dạng chữ.
 */
async function settle(page, { timeout = 30_000 } = {}) {
	await page.waitForLoadState("networkidle", { timeout }).catch(() => {});
	await page
		.evaluate(async () => {
			await document.fonts.ready;
			const imgs = Array.from(document.images);
			await Promise.all(
				imgs.map((img) =>
					img.complete && img.naturalWidth > 0
						? img.decode().catch(() => {})
						: new Promise((res) => {
								img.addEventListener("load", res, { once: true });
								img.addEventListener("error", res, { once: true });
								setTimeout(res, 8000);
							}),
				),
			);
		})
		.catch(() => {});
	// Site đang chạy ở chế độ dev, nên Next.js chèn huy hiệu "N — Issues" ở góc màn
	// hình. Nó không thuộc giao diện sản phẩm, nên bị ẩn đi trước khi chụp.
	await page
		.addStyleTag({
			content: "nextjs-portal, #__next-build-watcher, [data-nextjs-toast] { display: none !important; }",
		})
		.catch(() => {});
	// Skeleton của react-query và hiệu ứng chuyển cảnh còn một nhịp nữa.
	await page.waitForTimeout(900);
}

/** Gỡ toast của react-hot-toast để nó không nằm đè lên ảnh. */
async function clearToasts(page) {
	await page
		.evaluate(() => {
			document.querySelectorAll("[class*='go'] , [role='status']").forEach((el) => {
				if (el.closest("div[style*='position: fixed']")) el.remove();
			});
			document
				.querySelectorAll("div[style*='z-index: 9999'], div[style*='z-index:9999']")
				.forEach((el) => el.remove());
		})
		.catch(() => {});
}

async function shoot(page, fileName, { fullPage = false } = {}) {
	await clearToasts(page);
	const file = path.join(OUT_DIR, fileName);
	await page.screenshot({ path: file, fullPage, animations: "disabled" });
	const { size } = await stat(file);
	log(`✔ ${fileName} (${(size / 1024).toFixed(0)} KB, ${fullPage ? "full page" : "khung nhìn"})`);
	return file;
}

/** Đổi bề cao khung nhìn cho một ảnh cần nhiều chỗ hơn; bề rộng luôn giữ 1440. */
async function resize(page, height) {
	await page.setViewportSize({ width: VIEWPORT.width, height });
}

// ---------------------------------------------------------------------------
// Các bước chụp
// ---------------------------------------------------------------------------
const STEPS = [
	{
		key: "trang-chu",
		file: "web-00-trang-chu.png",
		desc: "Trang chủ (thay cho mockup thiết kế)",
		async run(browser) {
			const page = await signIn(browser, "buyer", { ...VIEWPORT, height: 1100 });
			await page.goto(`${BASE_URL}/`, { waitUntil: "domcontentloaded" });
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},

	{
		key: "tim-kiem",
		file: "web-01-tim-kiem.png",
		desc: "Kết quả tìm kiếm, panel bộ lọc mở sẵn",
		async run(browser) {
			// Rail bộ lọc cao hơn 900px nên khung nhìn được kéo cao để lấy trọn
			// khoảng giá, tình trạng và khu vực trong cùng một khung.
			const page = await signIn(browser, "buyer", { ...VIEWPORT, height: 1350 });
			await page.goto(`${BASE_URL}/search?q=${encodeURIComponent(FIXTURES.searchQuery)}`, {
				waitUntil: "domcontentloaded",
			});
			await settle(page);
			// Rail là cột cố định trên desktop (md:col-span-3), không có nút bật/tắt —
			// nó đã mở sẵn. Chỉ cần chắc chắn nó đã dựng xong.
			await page.getByRole("heading", { name: "Bộ lọc" }).waitFor({ timeout: 20_000 });
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},

	{
		key: "chi-tiet-san-pham",
		file: "web-02-chi-tiet-san-pham.png",
		desc: "Chi tiết tin đăng ở chế độ giá thương lượng",
		async run(browser) {
			const page = await signIn(browser, "buyer", { ...VIEWPORT, height: 1250 });
			await page.goto(`${BASE_URL}/product/${FIXTURES.negotiableListingId}`, {
				waitUntil: "domcontentloaded",
			});
			await settle(page);
			// Khối giá niêm yết + nhãn "Có thể thương lượng" nằm cuối cột phải; thanh
			// hành động (Mua ngay) là thanh cố định đáy màn nên luôn có trong khung.
			await page
				.getByText("Có thể thương lượng")
				.first()
				.scrollIntoViewIfNeeded()
				.catch(() => {});
			await page.mouse.wheel(0, -120);
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},

	{
		key: "thuong-luong",
		file: "web-03-thuong-luong.png",
		desc: "Hộp thư có đề nghị giá còn hiệu lực (tài khoản người mua)",
		async run(browser) {
			const page = await signIn(browser, "buyer");
			const listingId = FIXTURES.negotiableListingId;

			// Đã có đề nghị nào còn hiệu lực chưa? Nếu chưa thì tạo một đề nghị mới
			// từ chính tài khoản người mua, đúng như quy trình thật trên giao diện.
			await page.goto(`${BASE_URL}/inbox?listing_id=${listingId}`, { waitUntil: "domcontentloaded" });
			await settle(page);
			// Một đề nghị còn hiệu lực luôn kèm một trong hai nút này — "Rút đề nghị" cho
			// người gửi, "Đồng ý mức giá này" cho người nhận.
			const hasActive = await page
				.getByRole("button", { name: /Rút đề nghị|Đồng ý mức giá này/ })
				.first()
				.isVisible()
				.catch(() => false);

			if (!hasActive) {
				log("chưa có đề nghị còn hiệu lực → tạo mới từ tài khoản người mua");
				await page.goto(`${BASE_URL}/product/${listingId}`, { waitUntil: "domcontentloaded" });
				await settle(page);
				await page.getByRole("button", { name: "Mua ngay", exact: true }).click();
				await page.getByRole("button", { name: /^Thương lượng giá/ }).click();
				await page.waitForSelector("#offer-form, form", { timeout: 15_000 });
				await page.getByPlaceholder("Ví dụ: 500000").fill("690000");
				await page
					.getByPlaceholder("Thương lượng thêm...")
					.fill("Mình lấy ngay hôm nay, bạn để giá này được không?")
					.catch(() => {});
				await page.getByRole("button", { name: "Gửi đề nghị" }).click();
				await page.waitForTimeout(3500);
			}

			await page.goto(`${BASE_URL}/inbox?listing_id=${listingId}`, { waitUntil: "domcontentloaded" });
			await settle(page);
			// Cuộn luồng chat xuống cuối để thẻ đề nghị mới nhất nằm trong khung.
			await page
				.evaluate(() => {
					for (const el of document.querySelectorAll("*")) {
						if (el.scrollHeight > el.clientHeight + 50 && getComputedStyle(el).overflowY !== "visible") {
							el.scrollTop = el.scrollHeight;
						}
					}
				})
				.catch(() => {});
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},

	{
		key: "thanh-toan",
		file: "web-04-thanh-toan.png",
		desc: "Trang thanh toán sau khi đã chọn địa chỉ nhận",
		async run(browser) {
			const page = await signIn(browser, "buyer", { ...VIEWPORT, height: 1300 });
			await page.goto(`${BASE_URL}/product/${FIXTURES.negotiableListingId}`, {
				waitUntil: "domcontentloaded",
			});
			await settle(page);
			// "Mua ngay" trên tin thương lượng hỏi lại; chọn mua theo giá niêm yết để
			// vào đúng trang thanh toán. Chỉ tạo *đơn nháp*, không thanh toán.
			await page.getByRole("button", { name: "Mua ngay", exact: true }).click();
			await page.getByRole("button", { name: /^Mua ngay với giá niêm yết/ }).click();
			await page.waitForURL(/\/checkout\?/, { timeout: 45_000 });
			await settle(page);
			// Địa chỉ mặc định được chọn sẵn nên bảng giá cước đã được hỏi ngay. Chờ đúng
			// các ô chọn đơn vị vận chuyển hiện ra, không chỉ chờ tiêu đề — nếu không thì
			// ảnh dính dòng "Đang tính phí vận chuyển...".
			await page
				.locator('input[name="shipping"]')
				.first()
				.waitFor({ state: "attached", timeout: 45_000 })
				.catch(() => log("⚠ giá cước chưa về kịp — ảnh có thể còn dòng 'Đang tính phí vận chuyển'"));
			await page
				.locator('input[name="payment"]')
				.first()
				.waitFor({ state: "attached", timeout: 20_000 })
				.catch(() => {});
			await settle(page);
			await shoot(page, this.file, { fullPage: true });
			await page.context().close();
		},
	},

	{
		key: "theo-doi-don",
		file: "web-05-theo-doi-don.png",
		desc: "Chi tiết đơn đang trong khâu giao / chờ xác nhận nhận hàng",
		async run(browser) {
			const page = await signIn(browser, "buyer", { ...VIEWPORT, height: 1050 });
			await page.goto(`${BASE_URL}/account/orders`, { waitUntil: "domcontentloaded" });
			await settle(page);
			const href = await pickHref(page, "/account/orders/ord_", FIXTURES.orderStatePreference);
			await page.goto(`${BASE_URL}${href}`, { waitUntil: "domcontentloaded" });
			await settle(page);
			await page.getByText("Trạng thái đơn hàng").waitFor({ timeout: 20_000 });
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},

	{
		key: "hoan-tien",
		file: "web-06-hoan-tien.png",
		desc: "Chi tiết yêu cầu hoàn tiền kèm ảnh bằng chứng",
		async run(browser) {
			// Xem từ phía người bán: đây là phía có nút chuyển vụ việc cho ShopNexus.
			const page = await signIn(browser, "seller");
			await page.goto(`${BASE_URL}/account/refunds`, { waitUntil: "domcontentloaded" });
			await settle(page);
			const href = await pickHref(page, "/account/refunds/rfd_", FIXTURES.refundStatePreference);
			await page.goto(`${BASE_URL}${href}`, { waitUntil: "domcontentloaded" });
			await settle(page);
			// Trang lỗi cũng mang chữ "Yêu cầu hoàn tiền", nên phải bắt chính thông báo
			// hỏng thay vì chỉ chờ tiêu đề xuất hiện.
			const broken = page.getByText(/không tải đư[ơợ]c|không tìm thấy/i).first();
			if (await broken.isVisible().catch(() => false)) {
				throw new Error(`trang hoàn tiền ${href} không tải được nội dung`);
			}
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},

	{
		key: "hang-doi-phieu",
		file: "web-07-hang-doi-phieu.png",
		desc: "Hàng đợi phiếu hỗ trợ trong khu quản trị",
		async run(browser) {
			const page = await signIn(browser, "admin", { ...VIEWPORT, height: 1200 });
			await page.goto(`${BASE_URL}/admin/tickets`, { waitUntil: "domcontentloaded" });
			await settle(page);
			await page.getByText("Hàng đợi yêu cầu hỗ trợ").waitFor({ timeout: 25_000 });
			await settle(page);
			await shoot(page, this.file);
			await page.context().close();
		},
	},
];

// ---------------------------------------------------------------------------
// Chạy
// ---------------------------------------------------------------------------
if (flag("list")) {
	for (const s of STEPS) console.log(`${s.key.padEnd(20)} ${s.file.padEnd(32)} ${s.desc}`);
	process.exit(0);
}

const only = value("only", "");
const wanted = only ? new Set(only.split(",").map((s) => s.trim())) : null;
const steps = STEPS.filter((s) => !wanted || wanted.has(s.key));
if (steps.length === 0) {
	console.error(`Không có bước nào khớp --only=${only}. Xem --list.`);
	process.exit(1);
}

await mkdir(OUT_DIR, { recursive: true });
console.log(`Site : ${BASE_URL}`);
console.log(`Ảnh  : ${OUT_DIR}`);
console.log(`Bước : ${steps.map((s) => s.key).join(", ")}\n`);

const browser = await chromium.launch({ headless: !flag("headed") });
const results = [];
for (const step of steps) {
	console.log(`\n── ${step.key} — ${step.desc}`);
	try {
		await step.run(browser);
		results.push([step.file, "OK", ""]);
	} catch (err) {
		console.error(`  ✖ ${step.key}: ${err.message}`);
		results.push([step.file, "LỖI", err.message.split("\n")[0].slice(0, 110)]);
	}
}
await browser.close();

console.log("\n=== Kết quả ===");
for (const [file, status, note] of results) console.log(`${status.padEnd(5)} ${file} ${note}`);
if (existsSync(OUT_DIR)) {
	const files = (await readdir(OUT_DIR)).filter((f) => f.endsWith(".png")).sort();
	console.log(`\n${files.length} ảnh trong ${OUT_DIR}`);
}
process.exit(results.some(([, s]) => s === "LỖI") ? 1 : 0);

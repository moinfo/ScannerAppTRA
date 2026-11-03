const puppeteer = require('puppeteer')
  const scrapeOnce = async (code, time) => {
      console.log("start puppeteer " + (new Date()).getTime());
      const hrs = time.slice(0, 2)
      const minutes = time.slice(2, 4)
      const seconds = time.slice(4, 6)
      const timeStr = `${hrs}:${minutes}:${seconds}`
      const url = `https://verify.tra.go.tz/${code}_${time}`
      const browser = await puppeteer.launch({ args: ['--no-sandbox'] })
      try {
          const page = await browser.newPage()
          await page.goto(url, { timeout: 30000, waitUntil: 'networkidle0' })
          console.log("start evaluating");
          const currentUrl = decodeURIComponent(page.url())
          const invoiceAlreadyLoaded = await page.$(".invoice-header")
          if (!invoiceAlreadyLoaded && currentUrl !== `https://verify.tra.go.tz/Verify/Verified?Secret=${timeStr}`) {
              const input = await page.waitForSelector("input[type='text'], .single-line", { visible: true, timeout: 15000 })
              if (input != null) {
                  console.log("filling input");
                  await input.type(`${code}`);
                  await page.waitForSelector("button[type='submit']", { timeout: 15000 });
                  await page.click("button[type='submit']");
                  await page.waitForSelector("#HH", { visible: true, timeout: 15000 })
                  await page.select('#HH', hrs);
                  await page.select('#MM', minutes);
                  await page.select('#SS', seconds);
                  await page.waitForSelector("button[type='button']", { timeout: 15000 });
                  await page.click("button[type='button']");
                  await page.waitForSelector(".invoice-header", { timeout: 15000 });
              }
          }
          console.log("required selector available " + (new Date()).getTime());
          const scrapedData = await page.evaluate(() => {
              let results = [];
              let items = [];
              function getValueAfterBold(b) {
                  let s = b.nextElementSibling;
                  if (s && s.tagName === 'SPAN') return s.textContent.trim();
                  let n = b.nextSibling;
                  while (n) {
                      if (n.nodeType === 3) { const t = n.textContent.trim(); if (t) return t; }
                      if (n.nodeType === 1 && n.tagName === 'SPAN') return n.textContent.trim();
                      n = n.nextSibling;
                  }
                  return '';
              }
              const tbodies = document.querySelectorAll('table tbody');
              const fields = {};
              document.querySelectorAll('.invoice-header b, .invoice-info b').forEach(b => {
                  const key = b.textContent.replace(/:/g, '').replace(/\s+/g, ' ').trim().toUpperCase();
                  if (key && !(key in fields)) fields[key] = getValueAfterBold(b);
              });
              const f = k => fields[k] || '';
              const titleLines = Array.from((document.querySelector('.invoice-header') || document).querySelectorAll('h4 b')).map(e => e.textContent.trim()).filter(Boolean);
              const companyName = titleLines[0] || '';
              const poBox = titleLines.slice(1).join(', ');
              const mobile = f('MOBILE');
              const tin = f('TIN');
              const vrn = f('VRN');
              const serialNo = f('SERIAL NO');
              const uin = f('UIN');
              const taxOffice = f('TAX OFFICE');
              const customerName = f('CUSTOMER NAME');
              const customerIdType = f('CUSTOMER ID TYPE');
              const customerId = f('CUSTOMER ID');
              const customerMobile = f('CUSTOMER MOBILE');
              const receiptNumber = f('RECEIPT NO');
              const zNumber = f('Z NUMBER');
              const receiptDate = f('RECEIPT DATE');
              const receiptTime = f('RECEIPT TIME');
              let receiptVerificationCode = '';
              const m = document.body.innerText.match(/RECEIPT VERIFICATION CODE\s*\n\s*(\S+)/);
              if (m) receiptVerificationCode = m[1];
              let itemsTable = null, totalsTable = null;
              for (let i = 0; i < tbodies.length; i++) {
                  const r = tbodies[i].children[0];
                  if (!r) continue;
                  const c = r.children[0] ? r.children[0].innerText.trim().toUpperCase() : '';
                  if (c.includes('TOTAL EXCL') || c.includes('TAX RATE')) { totalsTable = tbodies[i]; }
                  else if (c && !c.includes('TOTAL') && !c.includes('DESCRIPTION')) { if (!itemsTable) itemsTable = tbodies[i]; }
              }
              if (itemsTable) {
                  Array.from(itemsTable.children).forEach(row => {
                      if (row.children.length >= 3) items.push({ 'item_description': row.children[0].innerText.trim(), 'item_qty':
  parseInt(row.children[1].innerText.trim()) || 1, 'item_amount': parseFloat(row.children[2].innerText.trim().replace(/,/g, '')) || 0 });
                  });
              }
              let receiptTotalExclOfTax = 0, receiptTotalDiscount = 0, receiptTotalTax = 0, receiptTotalInclOfTax = 0;
              if (totalsTable) {
                  Array.from(totalsTable.children).forEach(row => {
                      if (row.children.length >= 2) {
                          const l = row.children[0].innerText.trim().toUpperCase();
                          const v = parseFloat(row.children[1].innerText.trim().replace(/,/g, '')) || 0;
                          if (l.includes('TOTAL EXCL')) receiptTotalExclOfTax = v;
                          else if (l.includes('DISCOUNT')) receiptTotalDiscount = v;
                          else if (l.includes('TOTAL TAX') && !l.includes('INCL')) receiptTotalTax = v;
                          else if (l.includes('TOTAL INCL')) receiptTotalInclOfTax = v;
                      }
                  });
              }
              results.push({ 'company_name': companyName, 'p_o_box': poBox, 'mobile': mobile, 'tin': tin, 'vrn': vrn, 'serial_no': serialNo, 'uin': uin,
  'tax_office': taxOffice, 'customer_name': customerName, 'customer_id_type': customerIdType, 'customer_id': customerId, 'customer_mobile': customerMobile,
  'receipt_number': receiptNumber, 'receipt_z_number': zNumber, 'receipt_date': receiptDate, 'receipt_time': receiptTime, 'receipt_verification_code':
  receiptVerificationCode, 'items': items, 'receipt_total_excl_of_tax': receiptTotalExclOfTax, 'receipt_total_discount': receiptTotalDiscount, 'receipt_total_tax':
  receiptTotalTax, 'receipt_total_incl_of_tax': receiptTotalInclOfTax });
              return results;
          });
          await browser.close()
          return scrapedData
      } catch (error) {
          await browser.close()
          throw error
      }
  }
  const RETRYABLE = /net::ERR_(?!CERT)|Navigation timeout|TimeoutError/
  const scrapeTra = async (code, time, attempts = 3) => {
      let lastErr
      for (let i = 1; i <= attempts; i++) {
          try {
              return await scrapeOnce(code, time)
          } catch (err) {
              lastErr = err
              console.log(`Attempt ${i}/${attempts} failed: ${err.message}`)
              if (i === attempts || !RETRYABLE.test(String(err))) break
              await new Promise(r => setTimeout(r, 1500 * i))
          }
      }
      throw lastErr
  }
  module.exports.scrapeTra = scrapeTra

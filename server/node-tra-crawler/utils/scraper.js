const puppeteer = require('puppeteer')

const scrapeTra = async (code, time) => {
    console.log("start puppeteer " + (new Date()).getTime());

    const hrs = time.slice(0, 2)
    const minutes = time.slice(2, 4)
    const seconds = time.slice(4, 6)

    const timeStr = `${hrs}:${minutes}:${seconds}`
    const url = `https://verify.tra.go.tz/${code}_${time}`

    const browser = await puppeteer.launch({
        args: ['--no-sandbox']
    })

    try {
        const page = await browser.newPage()
        await page.goto(url, {
            timeout: 30000,
            waitUntil: 'networkidle0',
        })

        console.log("start evaluating");

        // Fix: decode URL before comparing (TRA encodes colons as %3A)
        const currentUrl = decodeURIComponent(page.url())
        if (currentUrl !== `https://verify.tra.go.tz/Verify/Verified?Secret=${timeStr}`) {
            // Need to fill in the verification form
            const input = await page.waitForSelector("input[type='text'], .single-line", { visible: true, timeout: 15000 })

            if (input != null) {
                console.log("filling input");
                await input.type(`${code}`);
                const submitBtn = "button[type='submit']";
                await page.waitForSelector(submitBtn, { timeout: 15000 });
                await page.click(submitBtn);

                await page.waitForSelector("#HH", { visible: true, timeout: 15000 })

                page.select('#HH', hrs);
                page.select('#MM', minutes);
                page.select('#SS', seconds);

                const submitBtn2 = "button[type='button']";
                await page.waitForSelector(submitBtn2, { timeout: 15000 });
                await page.click(submitBtn2);

                // Wait for the receipt to load
                await page.waitForSelector(".invoice-header", { timeout: 15000 });
            }
        }

        console.log("required selector available " + (new Date()).getTime());

        const scrapedData = await page.evaluate(() => {
            let results = [];
            let items = [];

            // Helper: get value from the next <span> sibling after a <b> element
            // Handles both old format (text node) and new format (<span> element)
            function getValueAfterBold(bElement) {
                // Check next element sibling (new format: <b>LABEL:</b><span>value</span>)
                let sibling = bElement.nextElementSibling;
                if (sibling && sibling.tagName === 'SPAN') {
                    return sibling.textContent.trim();
                }
                // Fallback: next text node (old format: <b>LABEL:</b> value)
                let nextNode = bElement.nextSibling;
                while (nextNode) {
                    if (nextNode.nodeType === Node.TEXT_NODE) {
                        const text = nextNode.textContent.trim();
                        if (text) return text;
                    }
                    if (nextNode.nodeType === Node.ELEMENT_NODE && nextNode.tagName === 'SPAN') {
                        return nextNode.textContent.trim();
                    }
                    nextNode = nextNode.nextSibling;
                }
                return '';
            }

            // invoice header section - all <b> elements in .invoice-header divs
            const invoiceHeader = document.querySelectorAll(".invoice-header b");

            // invoice info section - company details
            const invoiceInfo = document.querySelectorAll(".invoice-info .invoice-col b");

            // invoice tables
            const invoiceTable = document.querySelectorAll('table tbody');

            // company name (first bold in header, usually inside an <h4>)
            const companyName = invoiceHeader[0] ? invoiceHeader[0].innerText.trim() : '';
            const poBox = invoiceInfo[0] ? invoiceInfo[0].innerText.trim() : '';
            const mobile = invoiceInfo[1] ? getValueAfterBold(invoiceInfo[1]) : '';
            const tin = invoiceInfo[2] ? getValueAfterBold(invoiceInfo[2]) : '';
            const vrn = invoiceInfo[3] ? getValueAfterBold(invoiceInfo[3]) : '';
            const serialNo = invoiceInfo[4] ? getValueAfterBold(invoiceInfo[4]) : '';
            const uin = invoiceInfo[5] ? getValueAfterBold(invoiceInfo[5]) : '';
            const taxOffice = invoiceInfo[6] ? getValueAfterBold(invoiceInfo[6]) : '';

            // customer
            const customerName = invoiceHeader[1] ? getValueAfterBold(invoiceHeader[1]) : '';
            const customerIdType = invoiceHeader[2] ? getValueAfterBold(invoiceHeader[2]) : '';
            const customerId = invoiceHeader[3] ? getValueAfterBold(invoiceHeader[3]) : '';
            const customerMobile = invoiceHeader[4] ? getValueAfterBold(invoiceHeader[4]) : '';

            // receipt
            const receiptNumber = invoiceHeader[5] ? getValueAfterBold(invoiceHeader[5]) : '';
            const zNumber = invoiceHeader[6] ? getValueAfterBold(invoiceHeader[6]) : '';
            const receiptDate = invoiceHeader[7] ? getValueAfterBold(invoiceHeader[7]) : '';
            const receiptTime = invoiceHeader[8] ? getValueAfterBold(invoiceHeader[8]) : '';

            // verification code - try multiple approaches
            let receiptVerificationCode = '';
            try {
                const headers = document.querySelectorAll(".invoice-header");
                if (headers[3] && headers[3].children[1]) {
                    receiptVerificationCode = headers[3].children[1].firstChild.innerText.trim();
                }
            } catch (e) {
                // Fallback: extract from page text
                const bodyText = document.body.innerText;
                const match = bodyText.match(/RECEIPT VERIFICATION CODE\s*\n\s*(\S+)/);
                if (match) receiptVerificationCode = match[1];
            }

            // Find the items table and totals table
            let itemsTable = null;
            let totalsTable = null;

            for (let i = 0; i < invoiceTable.length; i++) {
                const firstRow = invoiceTable[i].children[0];
                if (!firstRow) continue;
                const firstCell = firstRow.children[0] ? firstRow.children[0].innerText.trim().toUpperCase() : '';
                if (firstCell.includes('TOTAL EXCL') || firstCell.includes('TAX RATE')) {
                    totalsTable = invoiceTable[i];
                } else if (firstCell && !firstCell.includes('TOTAL') && !firstCell.includes('DESCRIPTION')) {
                    // This is likely the items table (has actual item data)
                    if (!itemsTable) itemsTable = invoiceTable[i];
                }
            }

            // items
            if (itemsTable && itemsTable.children.length > 0) {
                Array.from(itemsTable.children).forEach((item) => {
                    if (item.children.length >= 3) {
                        items.push({
                            'item_description': item.children[0].innerText.trim(),
                            'item_qty': parseInt(item.children[1].innerText.trim()) || 1,
                            'item_amount': parseFloat(item.children[2].innerText.trim().replace(/,/g, '')) || 0
                        });
                    }
                });
            }

            // prices/totals
            let receiptTotalExclOfTax = 0;
            let receiptTotalDiscount = 0;
            let receiptTotalTax = 0;
            let receiptTotalInclOfTax = 0;

            if (totalsTable) {
                Array.from(totalsTable.children).forEach(row => {
                    if (row.children.length >= 2) {
                        const label = row.children[0].innerText.trim().toUpperCase();
                        const value = parseFloat(row.children[1].innerText.trim().replace(/,/g, '')) || 0;
                        if (label.includes('TOTAL EXCL')) {
                            receiptTotalExclOfTax = value;
                        } else if (label.includes('DISCOUNT')) {
                            receiptTotalDiscount = value;
                        } else if (label.includes('TOTAL TAX') && !label.includes('INCL')) {
                            receiptTotalTax = value;
                        } else if (label.includes('TOTAL INCL')) {
                            receiptTotalInclOfTax = value;
                        }
                    }
                });
            }

            results.push({
                'company_name': companyName,
                'p_o_box': poBox,
                'mobile': mobile,
                'tin': tin,
                'vrn': vrn,
                'serial_no': serialNo,
                'uin': uin,
                'tax_office': taxOffice,
                'customer_name': customerName,
                'customer_id_type': customerIdType,
                'customer_id': customerId,
                'customer_mobile': customerMobile,
                'receipt_number': receiptNumber,
                'receipt_z_number': zNumber,
                'receipt_date': receiptDate,
                'receipt_time': receiptTime,
                'receipt_verification_code': receiptVerificationCode,
                'items': items,
                'receipt_total_excl_of_tax': receiptTotalExclOfTax,
                'receipt_total_discount': receiptTotalDiscount,
                'receipt_total_tax': receiptTotalTax,
                'receipt_total_incl_of_tax': receiptTotalInclOfTax,
            });

            return results;
        });

        await browser.close()
        return scrapedData
    } catch (error) {
        await browser.close()
        throw error
    }
}

module.exports.scrapeTra = scrapeTra

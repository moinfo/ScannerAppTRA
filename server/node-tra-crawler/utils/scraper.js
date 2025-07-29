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
    const page = await browser.newPage()
    await page.goto(url, {
        timeout: 0,
        waitUntil: 'networkidle0',
    })

    console.log("start evaluating");

    // await page.screenshot({
    //     path: 'page1.png'
    // })

    if (page.url() != `https://verify.tra.go.tz/Verify/Verified?Secret=${timeStr}`) {
        const input = await page.waitForSelector(".single-line", { visible: true, timeout: 0 })

        if (input != null) {
            console.log("filling input");
            await page.type('.single-line', `${code}`);
            const submitBtn = "button[type='submit']";
            await page.waitForSelector(submitBtn);
            await page.click(submitBtn);

            await page.waitForSelector("#HH", { visible: true, timeout: 0 })

            page.select('#HH', hrs);
            page.select('#MM', minutes);
            page.select('#SS', seconds);

            const submitBtn2 = "button[type='button']";
            await page.waitForSelector(submitBtn2);
            await page.click(submitBtn2);
        }

        // await page.screenshot({
        //     path: 'page2.png'
        // })
    }

    console.log("required selector available " + (new Date()).getTime());

    console.log("starting data extraction");

    const scrapedData = await page.evaluate(() => {
        let results = [];
        let items = [];

        // Check if the page has loaded properly and has the expected elements
        const invoiceHeader = document.querySelectorAll(".invoice-header b");
        const invoiceInfo = document.querySelectorAll(".invoice-info .invoice-col b");
        const invoiceTable = document.querySelectorAll('.table table.table tbody');

        console.log('Found elements:', {
            invoiceHeader: invoiceHeader.length,
            invoiceInfo: invoiceInfo.length,
            invoiceTable: invoiceTable.length
        });

        // Check for alternative receipt formats (like TANESCO)
        const bodyText = document.body.innerText || document.body.textContent || '';
        console.log('Page content preview:', bodyText.substring(0, 500));

        // Try to extract receipt data from different possible formats
        let extractedData = null;

        // Priority 1: Utility company format (TANESCO style) - check first
        if (bodyText.includes('TANZANIA ELECTRIC SUPPLY COMPANY') || 
            bodyText.includes('RECEIPT VERIFICATION CODE') ||
            bodyText.includes('TAX OFFICE: Tax Office Large Taxpayer')) {
            console.log('Using utility company receipt format');
            extractedData = extractUtilityFormat(bodyText);
        }
        // Priority 2: Standard business receipt format
        else if (invoiceHeader.length > 0 && invoiceInfo.length > 0 && invoiceTable.length > 0) {
            console.log('Using standard business receipt format');
            extractedData = extractStandardFormat(invoiceHeader, invoiceInfo, invoiceTable);
        }
        // Priority 3: Plain text format
        else if (bodyText.includes('TIN:') && bodyText.includes('VRN:')) {
            console.log('Using plain text receipt format');
            extractedData = extractPlainTextFormat(bodyText);
        }
        else {
            throw new Error(`Unsupported receipt format. Available elements: invoiceHeader=${invoiceHeader.length}, invoiceInfo=${invoiceInfo.length}, invoiceTable=${invoiceTable.length}. Content preview: ${bodyText.substring(0, 200)}`);
        }

        function extractUtilityFormat(text) {
            console.log('Extracting utility format data');
            const data = {};
            
            // Extract company name
            const companyMatch = text.match(/([A-Z\s]+(?:COMPANY|LTD|LIMITED))/);
            data.company_name = companyMatch ? companyMatch[1].trim() : 'TANZANIA ELECTRIC SUPPLY COMPANY LTD';
            
            // Extract basic info using regex patterns with proper line endings
            data.tin = extractField(text, /TIN:\s*(\d+)/);
            data.vrn = extractField(text, /VRN:\s*([A-Z0-9]+)/);
            data.serial_no = extractField(text, /SERIAL NO:\s*([A-Z0-9]+)/);
            data.uin = extractField(text, /UIN:\s*([A-Z0-9-]+)/);
            data.tax_office = extractField(text, /TAX OFFICE:\s*([^\r\n]+)/);
            
            // Extract customer info
            data.customer_name = extractField(text, /CUSTOMER NAME:\s*([^\r\n]+)/);
            data.customer_id_type = extractField(text, /CUSTOMER ID TYPE:\s*([^\r\n]+)/);
            data.customer_id = extractField(text, /CUSTOMER ID:\s*([^\r\n]+)/);
            data.customer_mobile = extractField(text, /CUSTOMER MOBILE:\s*([^\r\n]+)/);
            
            // Extract receipt info
            data.receipt_number = extractField(text, /RECEIPT NO:\s*([^\r\n]+)/);
            data.receipt_z_number = extractField(text, /Z NUMBER:\s*([^\r\n]+)/);
            data.receipt_date = extractField(text, /RECEIPT DATE:\s*([^\r\n]+)/);
            data.receipt_time = extractField(text, /RECEIPT TIME:\s*([^\r\n]+)/);
            data.receipt_verification_code = extractField(text, /RECEIPT VERIFICATION CODE[\s\r\n]*([A-Z0-9]+)/);
            
            // Extract totals
            data.receipt_total_excl_of_tax = parseFloat((extractField(text, /TOTAL EXCL OF TAX:\s*([\d,]+\.?\d*)/)||'0').replace(/,/g, ''));
            data.receipt_total_tax = parseFloat((extractField(text, /TOTAL TAX:\s*([\d,]+\.?\d*)/)||'0').replace(/,/g, ''));
            data.receipt_total_incl_of_tax = parseFloat((extractField(text, /TOTAL INCL OF TAX:\s*([\d,]+\.?\d*)/)||'0').replace(/,/g, ''));
            
            // Extract additional tax details (using backend-expected field names)
            data.tax_rate_a = extractField(text, /TAX RATE A \((\d+%)\)/);
            data.receipt_rea = parseFloat((extractField(text, /REA:\s*([\d,]+\.?\d*)/)||'0').replace(/,/g, ''));
            data.receipt_ewura = parseFloat((extractField(text, /EWURA:\s*([\d,]+\.?\d*)/)||'0').replace(/,/g, ''));
            data.receipt_property_tax = parseFloat((extractField(text, /PROPERTY TAX:\s*([\d,]+\.?\d*)/)||'0').replace(/,/g, ''));
            
            // Extract purchased items
            data.items = extractPurchasedItems(text);
            
            // Extract invoice adjustments
            data.adjustments = extractInvoiceAdjustments(text);
            
            // Extract invoice payments
            data.payments = extractInvoicePayments(text);
            
            // Set additional fields
            data.p_o_box = extractField(text, /P\.\s*O\.\s*BOX\s*([^\r\n]+)/);
            data.mobile = extractField(text, /MOBILE:\s*([^\r\n]+)/);
            data.receipt_total_discount = 0; // Usually 0 for utility bills
            
            console.log('Extracted utility data:', data);
            return data;
        }
        
        function extractField(text, regex) {
            const match = text.match(regex);
            return match ? match[1].trim() : '';
        }
        
        function extractPurchasedItems(text) {
            const items = [];
            
            // Extract items between "Purchased Items" and various end markers
            const itemsMatch = text.match(/Purchased Items[\s\S]*?Description\s+Qty\s+Amount([\s\S]*?)(?:Invoice Adjustments|Invoice Payments|TOTAL EXCL OF TAX|TOTAL TAX|$)/);
            
            if (itemsMatch) {
                const itemsText = itemsMatch[1];
                console.log('Items text to parse:', JSON.stringify(itemsText));
                
                // Split into lines and process each line
                const lines = itemsText.split('\n');
                
                for (const line of lines) {
                    const trimmedLine = line.trim();
                    if (!trimmedLine || trimmedLine.length < 3) continue;
                    
                    // Skip obvious non-item lines
                    if (trimmedLine.toLowerCase().includes('description') || 
                        trimmedLine.toLowerCase().includes('total') ||
                        trimmedLine.match(/^[\s\-=]+$/)) {
                        continue;
                    }
                    
                    let match = null;
                    let description, qty, amount;
                    
                    // Try multiple patterns to handle different receipt formats:
                    
                    // Pattern 1: "Description: Qty Amount" (TANESCO utility format)
                    match = trimmedLine.match(/^(.+?):\s+(\d+)\s+([\d,]+\.?\d*)$/);
                    if (match) {
                        description = match[1].trim();
                        qty = parseInt(match[2]);
                        amount = parseFloat(match[3].replace(/,/g, ''));
                    }
                    
                    // Pattern 2: "Description    Qty    Amount" (standard business format with spaces)
                    if (!match) {
                        match = trimmedLine.match(/^(.+?)\s+(\d+)\s+([\d,]+\.?\d*)$/);
                        if (match) {
                            description = match[1].trim();
                            qty = parseInt(match[2]);
                            amount = parseFloat(match[3].replace(/,/g, ''));
                        }
                    }
                    
                    // Pattern 3: "Description\tQty\tAmount" (tab-separated)
                    if (!match) {
                        match = trimmedLine.match(/^(.+?)\t+(\d+)\t+([\d,]+\.?\d*)$/);
                        if (match) {
                            description = match[1].trim();
                            qty = parseInt(match[2]);
                            amount = parseFloat(match[3].replace(/,/g, ''));
                        }
                    }
                    
                    // Pattern 4: "Description|Qty|Amount" (pipe-separated)
                    if (!match) {
                        match = trimmedLine.match(/^(.+?)\|+(\d+)\|+([\d,]+\.?\d*)$/);
                        if (match) {
                            description = match[1].trim();
                            qty = parseInt(match[2]);
                            amount = parseFloat(match[3].replace(/,/g, ''));
                        }
                    }
                    
                    // Pattern 5: Handle lines where amount might have currency or other text
                    if (!match) {
                        // Look for any line that has: text, number, number (with potential formatting)
                        match = trimmedLine.match(/^(.+?)\s+(\d+)\s+.*?([\d,]+\.?\d+)/);
                        if (match) {
                            description = match[1].trim();
                            qty = parseInt(match[2]);
                            amount = parseFloat(match[3].replace(/,/g, ''));
                        }
                    }
                    
                    // If we found a match, validate and add it
                    if (match && description && !isNaN(qty) && !isNaN(amount)) {
                        // Additional validation
                        if (description.length > 1 && 
                            qty > 0 && 
                            amount >= 0 &&
                            !description.toLowerCase().match(/^(qty|amount|total|tax|description)$/)) {
                            
                            items.push({
                                description: description,
                                qty: qty,
                                amount: amount
                            });
                            
                            console.log(`✅ Extracted item: "${description}" | Qty: ${qty} | Amount: ${amount}`);
                        }
                    } else {
                        console.log(`❌ Could not parse line: "${trimmedLine}"`);
                    }
                }
            } else {
                console.log('❌ No "Purchased Items" section found in receipt');
            }
            
            console.log(`📦 Total items extracted: ${items.length}`);
            console.log('Final items array:', JSON.stringify(items, null, 2));
            return items;
        }
        
        function extractInvoiceAdjustments(text) {
            const adjustments = [];
            
            // Extract adjustments between "Invoice Adjustments" and "Invoice Payments"
            const adjustMatch = text.match(/Invoice Adjustments[\s\S]*?Type\s+Description\s+Amount([\s\S]*?)(?:Invoice Payments|TOTAL EXCL OF TAX|$)/);
            
            if (adjustMatch) {
                const adjustText = adjustMatch[1];
                // Match adjustment lines: Type Description Amount
                const adjustRegex = /(\w+)\s+([^0-9]+?)\s+([\d,]+\.?\d*)/g;
                let match;
                
                while ((match = adjustRegex.exec(adjustText)) !== null) {
                    adjustments.push({
                        type: match[1].trim(),
                        description: match[2].trim(),
                        amount: parseFloat(match[3].replace(/,/g, ''))
                    });
                }
            }
            
            console.log('Extracted adjustments:', adjustments);
            return adjustments;
        }
        
        function extractInvoicePayments(text) {
            const payments = [];
            
            // Extract payments between "Invoice Payments" and "TOTAL EXCL OF TAX"
            const paymentMatch = text.match(/Invoice Payments[\s\S]*?Type\s+Description\s+Amount([\s\S]*?)(?:TOTAL EXCL OF TAX|$)/);
            
            if (paymentMatch) {
                const paymentText = paymentMatch[1];
                // Match payment lines: Type Description Amount
                const paymentRegex = /(\w+)\s+([^0-9]+?)\s+([\d,]+\.?\d*)/g;
                let match;
                
                while ((match = paymentRegex.exec(paymentText)) !== null) {
                    payments.push({
                        type: match[1].trim(),
                        description: match[2].trim(),
                        amount: parseFloat(match[3].replace(/,/g, ''))
                    });
                }
            }
            
            console.log('Extracted payments:', payments);
            return payments;
        }

        function extractStandardFormat(invoiceHeader, invoiceInfo, invoiceTable) {
            console.log('Extracting standard format data');
            // This is the original extraction logic for standard business receipts
            const data = {};

            // company
            data.company_name = invoiceHeader[0].innerText.trim();
            data.p_o_box = invoiceInfo[0].innerText.trim();
            data.mobile = invoiceInfo[1].nextSibling.textContent.trim();
            data.tin = invoiceInfo[2].nextSibling.textContent.trim();
            data.vrn = invoiceInfo[3].nextSibling.textContent.trim();
            data.serial_no = invoiceInfo[4].nextSibling.textContent.trim();
            data.uin = invoiceInfo[5].nextSibling.textContent.trim();
            data.tax_office = invoiceInfo[6].nextSibling.textContent.trim();

            // customer
            data.customer_name = invoiceHeader[1].nextSibling.textContent.trim();
            data.customer_id_type = invoiceHeader[2].nextSibling.textContent.trim();
            data.customer_id = invoiceHeader[3].nextSibling.textContent.trim();
            data.customer_mobile = invoiceHeader[4].nextSibling.textContent.trim();

            // receipt
            data.receipt_number = invoiceHeader[5].nextSibling.textContent.trim();
            data.receipt_z_number = invoiceHeader[6].nextSibling.textContent.trim();
            data.receipt_date = invoiceHeader[7].nextSibling.textContent.trim();
            data.receipt_time = invoiceHeader[8].nextSibling.textContent.trim();
            
            // Fix the problematic line that causes the error
            try {
                const invoiceHeaderElements = document.querySelectorAll(".invoice-header");
                if (invoiceHeaderElements[3] && invoiceHeaderElements[3].children[1] && invoiceHeaderElements[3].children[1].firstChild) {
                    data.receipt_verification_code = invoiceHeaderElements[3].children[1].firstChild.innerText.trim();
                } else {
                    console.log("Could not find receipt verification code element");
                    data.receipt_verification_code = 'N/A';
                }
            } catch (e) {
                console.log("Error extracting receipt verification code:", e.message);
                data.receipt_verification_code = 'N/A';
            }

            // prices
            const noOFRows = invoiceTable[1].children.length;
            data.receipt_total_discount = 0;
            
            data.receipt_total_excl_of_tax = parseFloat(invoiceTable[1].children[0].children[1].innerText.trim().replaceAll(',', ''));
            
            if (noOFRows === 5) {
                data.receipt_total_discount = parseFloat(invoiceTable[1].children[1].children[1].innerText.trim().replaceAll(',', ''));
            }

            data.receipt_total_tax = parseFloat(invoiceTable[1].children[noOFRows - 2].children[1].innerText.trim().replaceAll(',', ''));
            data.receipt_total_incl_of_tax = parseFloat(invoiceTable[1].children[noOFRows - 1].children[1].innerText.trim().replaceAll(',', ''));

            // items
            data.items = [];
            if (invoiceTable[0].children.length > 0) {
                Array.from(invoiceTable[0].children).forEach((item) => {
                    data.items.push({
                        'item_description': item.children[0].innerText.trim(),
                        'item_qty': parseInt(item.children[1].innerText.trim()),
                        'item_amount': parseFloat(item.children[2].innerText.trim().replaceAll(',', ''))
                    });
                });
            }

            console.log('Extracted standard data:', data);
            return data;
        }

        function extractPlainTextFormat(text) {
            console.log('Extracting plain text format data');
            // Fallback for plain text receipts
            return extractUtilityFormat(text);
        }

        // Return the extracted data
        results.push(extractedData);
        return results;
    });

    await browser.close()
    return scrapedData
}

module.exports.scrapeTra = scrapeTra
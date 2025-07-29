const express = require('express')

const scraper = require('./utils/scraper')
const app = express()

app.get('/', (req, res) => {
    res.send('Hello, World');
})

app.get('/receipt/:code/:time', (req, res) => {
    console.log(`Receipt request: code=${req.params.code}, time=${req.params.time}`);
    
    const traReceipt = new Promise((resolve, reject) => {
        scraper
            .scrapeTra(req.params.code, req.params.time)
            .then(data => {
                console.log('Scraping successful');
                resolve(data);
            })
            .catch(err => {
                console.error('Scraping failed:', err);
                reject({
                    error: 'TRA scrape failed',
                    message: err.message || err.toString(),
                    code: req.params.code,
                    time: req.params.time,
                    timestamp: new Date().toISOString()
                });
            })
    })

    Promise.all([traReceipt])
        .then(data => {
            console.log('Sending success response');
            res.send(data[0][0])
        })
        .catch(err => {
            console.error('Sending error response:', err);
            res.status(500).json(err);
        })
})

app.listen(process.env.PORT || 3000, '0.0.0.0', () => {
    console.log('server running on all interfaces');
})
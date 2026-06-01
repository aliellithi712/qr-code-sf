import { LightningElement } from 'lwc';
import getCity from '@salesforce/apex/SitePdfController.getCity';
import getWeatherData from '@salesforce/apex/SitePdfController.getWeatherData';

export default class MyComponent extends LightningElement {
    city;
    weather;

    connectedCallback() {
        // Kick off the synchronous sequence wrapper safely
        this.initializeComponent();
    }

    async initializeComponent() {
        try {
            const urlParams = new URLSearchParams(window.location.search);
            const urlCity = urlParams.get('e');

            if (!urlCity) return;

            // 1. Enforce execution of getCity first
            const cityResult = await getCity({ input: urlCity });
            console.log('1. getCity finished:', cityResult);
            this.city = urlCity;

            // 2. This line WILL NOT run until getCity is fully resolved
            const secondResult = await getWeatherData({ Location: cityResult });
            console.log('2. Dependent call finished:', secondResult);
            this.weather = secondResult;

        } catch (error) {
            console.error('Error in sequence execution:', error);
        }
    }
}